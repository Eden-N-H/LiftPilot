//  ActiveWorkoutViewModel.swift

import Foundation
import Combine

/// Drives the Active Workout screen: logging sets, the rest timer, and
/// finishing or discarding the workout.
@MainActor
final class ActiveWorkoutViewModel: ObservableObject {
    struct PlannedSet: Hashable {
        let number: Int
        let weightKg: Double
        let reps: Int
    }

    struct ExerciseBlock: Identifiable {
        let exercise: Exercise
        let goal: LiftGoal?
        let prescription: SessionPrescription?
        let loggedSets: [ExerciseSet]
        let lastSessionSets: [ExerciseSet]

        var id: UUID { exercise.id }

        /// The next set of today's prescription, until all prescribed sets are logged.
        var nextPlannedSet: PlannedSet? {
            guard let prescription, loggedSets.count < prescription.sets else { return nil }
            return PlannedSet(
                number: loggedSets.count + 1,
                weightKg: prescription.weightKg,
                reps: prescription.targetReps
            )
        }

        var suggestedWeightKg: Double {
            nextPlannedSet?.weightKg
                ?? loggedSets.last?.weightKg
                ?? lastSessionSets.last?.weightKg
                ?? (exercise.isMainBarbellLift ? PlateCalculator.standardBarWeightKg : 0)
        }

        var suggestedReps: Int {
            nextPlannedSet?.reps ?? loggedSets.last?.reps ?? lastSessionSets.last?.reps ?? 8
        }

        var lastSessionSummary: String? {
            guard !lastSessionSets.isEmpty else { return nil }
            return lastSessionSets.map(\.summary).joined(separator: ", ")
        }
    }

    private struct UpNext {
        let block: ExerciseBlock
        let setNumber: Int
        let weightKg: Double
        let reps: Int
        let plannedTotal: Int?

        var setLabel: String {
            if let plannedTotal {
                return "Set \(setNumber) of \(plannedTotal)"
            }
            return "Set \(setNumber)"
        }
    }

    @Published private(set) var blocks: [ExerciseBlock] = []
    @Published private(set) var restEndsAt: Date?
    @Published private(set) var summary: WorkoutSummary?
    @Published private(set) var startedAt: Date = Date()
    @Published private(set) var workoutWasDiscarded = false
    @Published var errorMessage: String?

    let sessionID: UUID

    private let dependencies: AppDependencies
    private var addedExerciseIDs: [UUID] = []
    private var allExercises: [Exercise] = []
    private var currentUpNext: UpNextSet?

    init(sessionID: UUID, dependencies: AppDependencies) {
        self.sessionID = sessionID
        self.dependencies = dependencies

        allExercises = (try? dependencies.repository.fetchExercises()) ?? []

        // A fresh workout starts with the lifter's goal lifts already on the list.
        if let session = try? dependencies.repository.fetchSession(id: sessionID), session.sets.isEmpty {
            addedExerciseIDs = ((try? dependencies.repository.fetchActiveGoals()) ?? []).map(\.exerciseID)
        }
        reload()
    }

    var exercisesNotYetAdded: [Exercise] {
        allExercises.filter { exercise in !blocks.contains { $0.id == exercise.id } }
    }

    var totalSetsLogged: Int {
        blocks.reduce(0) { $0 + $1.loggedSets.count }
    }

    // MARK: - Loading

    func reload() {
        let repository = dependencies.repository
        do {
            guard let session = try repository.fetchSession(id: sessionID) else {
                errorMessage = "This workout could not be found. It may have been discarded."
                return
            }
            startedAt = session.startedAt

            let trainedIDs = session.exerciseIDsInOrder
            let order = trainedIDs + addedExerciseIDs.filter { !trainedIDs.contains($0) }

            blocks = order.compactMap { exerciseID in
                guard let exercise = allExercises.first(where: { $0.id == exerciseID }) else { return nil }
                let goal = try? repository.fetchActiveGoal(for: exerciseID)
                let prescription = goal.flatMap { try? dependencies.prescribeNextSession.execute(for: $0) }
                let history = (try? repository.fetchCompletedSets(for: exerciseID, since: nil)) ?? []
                let lastSession = LiftHistory.sessionRecords(from: history).last
                return ExerciseBlock(
                    exercise: exercise,
                    goal: goal,
                    prescription: prescription,
                    loggedSets: session.sets(for: exerciseID),
                    lastSessionSets: lastSession?.sets ?? []
                )
            }
        } catch {
            errorMessage = "This workout couldn't be loaded. Please try again."
        }
    }

    // MARK: - Logging

    /// Logs a set. Returns true when it was saved.
    @discardableResult
    func logSet(exerciseID: UUID, weightKg: Double, reps: Int) -> Bool {
        do {
            try dependencies.logWorkingSet.execute(
                sessionID: sessionID,
                exerciseID: exerciseID,
                weightKg: weightKg,
                reps: reps
            )
        } catch {
            errorMessage = ErrorMessage.forLifter(error)
            return false
        }
        errorMessage = nil
        reload()
        startRest(after: exerciseID)
        return true
    }

    /// One-tap logging: the lifter did exactly what was prescribed.
    func logPlannedSet(for block: ExerciseBlock) {
        guard let planned = block.nextPlannedSet else { return }
        logSet(exerciseID: block.exercise.id, weightKg: planned.weightKg, reps: planned.reps)
    }

    func deleteSet(_ set: ExerciseSet) {
        do {
            try dependencies.repository.deleteSet(id: set.id)
            reload()
            dependencies.snapshotPublisher.publish(workoutInProgress: true, restEndsAt: restEndsAt, upNext: currentUpNext)
        } catch {
            errorMessage = "That set couldn't be removed. Please try again."
        }
    }

    func addExercise(_ exercise: Exercise) {
        guard !blocks.contains(where: { $0.id == exercise.id }) else { return }
        addedExerciseIDs.append(exercise.id)
        reload()
    }

    // MARK: - Rest timer

    func skipRest() {
        restEndsAt = nil
        dependencies.restTimerNotifications.cancelRestComplete()
        dependencies.snapshotPublisher.publish(workoutInProgress: true, restEndsAt: nil, upNext: currentUpNext)
    }

    private func startRest(after exerciseID: UUID) {
        let endsAt = Date().addingTimeInterval(TimeInterval(TrainingPreferences.restDurationSeconds))
        restEndsAt = endsAt

        let upNext = nextUp(after: exerciseID)
        currentUpNext = upNext.map {
            UpNextSet(exerciseName: $0.block.exercise.name, setLabel: $0.setLabel, weightKg: $0.weightKg, reps: $0.reps)
        }

        if let upNext {
            dependencies.restTimerNotifications.scheduleRestComplete(at: endsAt, payload: payload(for: upNext))
        }
        dependencies.snapshotPublisher.publish(workoutInProgress: true, restEndsAt: endsAt, upNext: currentUpNext)
    }

    /// The set the lifter is most likely doing next: the rest of this lift's
    /// prescription, then another goal lift's prescription, then a repeat of
    /// the set just logged.
    private func nextUp(after exerciseID: UUID) -> UpNext? {
        let current = blocks.first { $0.id == exerciseID }

        if let current, let planned = current.nextPlannedSet {
            return UpNext(block: current, setNumber: planned.number, weightKg: planned.weightKg,
                          reps: planned.reps, plannedTotal: current.prescription?.sets)
        }
        if let other = blocks.first(where: { $0.nextPlannedSet != nil }), let planned = other.nextPlannedSet {
            return UpNext(block: other, setNumber: planned.number, weightKg: planned.weightKg,
                          reps: planned.reps, plannedTotal: other.prescription?.sets)
        }
        if let current, let lastSet = current.loggedSets.last {
            return UpNext(block: current, setNumber: current.loggedSets.count + 1, weightKg: lastSet.weightKg,
                          reps: lastSet.reps, plannedTotal: nil)
        }
        return nil
    }

    private func payload(for upNext: UpNext) -> RestCompletePayload {
        let exercise = upNext.block.exercise

        var barWeight: Double?
        var plates: [Double] = []
        if exercise.isMainBarbellLift {
            let breakdown = PlateCalculator.breakdown(forTotalKg: upNext.weightKg)
            barWeight = breakdown.barWeightKg
            plates = breakdown.platesPerSideKg
        }

        let lastSessionSets = upNext.block.lastSessionSets
        let comparableSet = lastSessionSets.indices.contains(upNext.setNumber - 1)
            ? lastSessionSets[upNext.setNumber - 1]
            : lastSessionSets.last
        let lastSessionLine = comparableSet.map { "Last session: \($0.summary)" }

        var goalLine: String?
        var goalProgress: Double?
        if let goal = upNext.block.goal,
           let forecast = try? dependencies.forecastGoalAchievement.execute(for: goal) {
            goalProgress = forecast.progressFraction
            let percent = Int((forecast.progressFraction * 100).rounded())
            goalLine = "Goal \(WeightFormatting.kg(goal.targetWeightKg)) · \(percent)% there"
        }

        return RestCompletePayload(
            exerciseName: exercise.name,
            setLabel: upNext.setLabel,
            weightKg: upNext.weightKg,
            reps: upNext.reps,
            barWeightKg: barWeight,
            platesPerSideKg: plates,
            lastSessionLine: lastSessionLine,
            goalLine: goalLine,
            goalProgress: goalProgress
        )
    }

    // MARK: - Finishing

    func finishWorkout() {
        do {
            summary = try dependencies.finishWorkoutSession.execute(sessionID: sessionID)
            errorMessage = nil
        } catch {
            errorMessage = ErrorMessage.forLifter(error)
            return
        }
        endWorkoutServices()
    }

    func discardWorkout() {
        do {
            try dependencies.repository.deleteSession(id: sessionID)
        } catch {
            errorMessage = "This workout couldn't be discarded. Please try again."
            return
        }
        endWorkoutServices()
        workoutWasDiscarded = true
    }

    private func endWorkoutServices() {
        restEndsAt = nil
        currentUpNext = nil
        dependencies.restTimerNotifications.cancelRestComplete()
        dependencies.snapshotPublisher.publish(workoutInProgress: false)
    }
}
