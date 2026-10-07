//  SampleTrainingHistory.swift

import Foundation

/// Creates six weeks of realistic bench press training so the forecast, chart
/// and widget can be demonstrated without waiting weeks for real data.
///
/// It goes through the real use cases (set goal, log sets, finish workouts),
/// so the sample data follows exactly the same rules as real training.
@MainActor
struct SampleTrainingHistory {
    private let repository: TrainingLogRepository
    private let setLiftGoal: SetLiftGoalUseCase
    private let logWorkingSet: LogWorkingSetUseCase
    private let finishWorkoutSession: FinishWorkoutSessionUseCase
    private let prescribeNextSession: PrescribeNextSessionUseCase

    init(dependencies: AppDependencies) {
        repository = dependencies.repository
        setLiftGoal = dependencies.setLiftGoal
        logWorkingSet = dependencies.logWorkingSet
        finishWorkoutSession = dependencies.finishWorkoutSession
        prescribeNextSession = dependencies.prescribeNextSession
    }

    /// Returns the number of sample workouts created.
    @discardableResult
    func load(now: Date = Date()) throws -> Int {
        guard try repository.fetchInProgressSession() == nil else {
            throw SampleTrainingHistoryError.workoutInProgress
        }

        let exercises = try repository.fetchExercises()
        guard let bench = exercises.first(where: { $0.name == "Bench Press" }),
              let row = exercises.first(where: { $0.name == "Barbell Row" }) else {
            throw SampleTrainingHistoryError.exercisesMissing
        }

        let calendar = Calendar.current
        guard let goalSetAt = calendar.date(byAdding: .day, value: -43, to: now) else {
            throw SampleTrainingHistoryError.exercisesMissing
        }

        let goal = try setLiftGoal.execute(
            exerciseID: bench.id,
            targetWeightKg: 102.5,
            referenceWeightKg: 77.5,
            referenceReps: 3,
            sessionsPerWeek: 2,
            replacingExistingGoal: true,
            now: goalSetAt
        )

        // One tough session (the 8th) shows how a missed session is handled.
        let missedSessionIndex = 7
        let sessionCount = 12

        for index in 0..<sessionCount {
            let dayOffset = -42 + Int((Double(index) * 3.5).rounded())
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let start = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day) else { continue }

            let session = try repository.startSession(at: start)
            let prescription = try prescribeNextSession.execute(for: goal)

            for setIndex in 0..<prescription.sets {
                var reps = prescription.targetReps
                if index == missedSessionIndex && setIndex == prescription.sets - 1 {
                    reps = ProgressionRules.minimumReps - 1
                }
                try logWorkingSet.execute(
                    sessionID: session.id,
                    exerciseID: bench.id,
                    weightKg: prescription.weightKg,
                    reps: reps,
                    loggedAt: start.addingTimeInterval(Double(300 + setIndex * 180))
                )
            }

            for setIndex in 0..<3 {
                try logWorkingSet.execute(
                    sessionID: session.id,
                    exerciseID: row.id,
                    weightKg: 50 + Double(index / 4) * 2.5,
                    reps: 10,
                    loggedAt: start.addingTimeInterval(Double(1_500 + setIndex * 150))
                )
            }

            try finishWorkoutSession.execute(sessionID: session.id, finishedAt: start.addingTimeInterval(3_600))
        }

        return sessionCount
    }
}

enum SampleTrainingHistoryError: LocalizedError {
    case workoutInProgress
    case exercisesMissing

    var errorDescription: String? {
        switch self {
        case .workoutInProgress:
            return "Finish or discard your current workout before loading sample training."
        case .exercisesMissing:
            return "The standard exercise list is missing, so sample training couldn't be created."
        }
    }
}
