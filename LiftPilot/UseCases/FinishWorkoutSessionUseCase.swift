//  FinishWorkoutSessionUseCase.swift

import Foundation

/// Finishes a workout and produces the coach's debrief for each goal lift.
///
/// Business rules:
/// - A workout can only be finished once, and only if at least one set was logged.
/// - Lifting the target weight (or more) on a goal lift marks that goal achieved.
/// - If the next prescription is a deload, the goal's planned timeline is
///   recalculated from the new, lower starting point.
@MainActor
struct FinishWorkoutSessionUseCase {
    private let repository: TrainingLogRepository
    private let prescribeNextSession: PrescribeNextSessionUseCase

    init(repository: TrainingLogRepository) {
        self.repository = repository
        self.prescribeNextSession = PrescribeNextSessionUseCase(repository: repository)
    }

    @discardableResult
    func execute(sessionID: UUID, finishedAt: Date = Date()) throws -> WorkoutSummary {
        let session: WorkoutSession?
        do {
            session = try repository.fetchSession(id: sessionID)
        } catch {
            throw FinishWorkoutSessionError.persistenceFailed
        }

        guard let session else {
            throw FinishWorkoutSessionError.workoutNotFound
        }
        guard session.isInProgress else {
            throw FinishWorkoutSessionError.workoutAlreadyFinished
        }
        guard !session.sets.isEmpty else {
            throw FinishWorkoutSessionError.noSetsLogged
        }

        let activeGoals: [LiftGoal]
        do {
            try repository.markSessionFinished(id: sessionID, at: finishedAt)
            activeGoals = try repository.fetchActiveGoals()
        } catch {
            throw FinishWorkoutSessionError.persistenceFailed
        }

        var debriefs: [GoalLiftDebrief] = []

        for goal in activeGoals {
            let goalLiftSets = session.sets(for: goal.exerciseID)
            guard !goalLiftSets.isEmpty else { continue }

            let exercise = try? repository.fetchExercise(id: goal.exerciseID)
            let exerciseName = exercise?.name ?? "Goal lift"
            let record = LiftSessionRecord(sessionID: session.id, date: session.startedAt, sets: goalLiftSets)

            let liftedTarget = goalLiftSets.contains { $0.weightKg + 0.001 >= goal.targetWeightKg }
            if liftedTarget {
                var achievedGoal = goal
                achievedGoal.status = .achieved
                achievedGoal.achievedAt = finishedAt
                do {
                    try repository.saveGoal(achievedGoal)
                } catch {
                    throw FinishWorkoutSessionError.persistenceFailed
                }
                debriefs.append(GoalLiftDebrief(
                    goalID: goal.id,
                    exerciseName: exerciseName,
                    outcome: record.outcome,
                    nextPrescription: nil,
                    goalAchieved: true,
                    planWasRecalculated: false
                ))
                continue
            }

            let nextPrescription: SessionPrescription
            do {
                nextPrescription = try prescribeNextSession.execute(for: goal)
            } catch {
                throw FinishWorkoutSessionError.persistenceFailed
            }

            var planWasRecalculated = false
            if case .deload = nextPrescription.decision, let exercise {
                var replannedGoal = goal
                replannedGoal.plannedCompletionDate = GoalTimelinePlanner.plannedCompletionDate(
                    startingWeightKg: nextPrescription.weightKg,
                    incrementKg: exercise.progressionIncrementKg,
                    targetWeightKg: goal.targetWeightKg,
                    sessionsPerWeek: goal.sessionsPerWeek,
                    from: finishedAt
                )
                do {
                    try repository.saveGoal(replannedGoal)
                } catch {
                    throw FinishWorkoutSessionError.persistenceFailed
                }
                planWasRecalculated = true
            }

            debriefs.append(GoalLiftDebrief(
                goalID: goal.id,
                exerciseName: exerciseName,
                outcome: record.outcome,
                nextPrescription: nextPrescription,
                goalAchieved: false,
                planWasRecalculated: planWasRecalculated
            ))
        }

        return WorkoutSummary(
            sessionID: session.id,
            startedAt: session.startedAt,
            finishedAt: finishedAt,
            totalSets: session.sets.count,
            exercisesTrained: session.exerciseIDsInOrder.count,
            goalDebriefs: debriefs
        )
    }
}

enum FinishWorkoutSessionError: LocalizedError {
    case workoutNotFound
    case workoutAlreadyFinished
    case noSetsLogged
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .workoutNotFound:
            return "We couldn't find this workout. It may have been discarded."
        case .workoutAlreadyFinished:
            return "This workout has already been finished. Your sets are saved in your history."
        case .noSetsLogged:
            return "You haven't logged any sets yet. Log at least one set, or discard the workout instead."
        case .persistenceFailed:
            return "Your workout couldn't be saved. Please try finishing it again."
        }
    }
}
