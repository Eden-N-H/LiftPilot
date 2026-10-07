//  PrescribeNextSessionUseCase.swift

import Foundation

/// Tells the lifter what to do on a goal lift in their next session, the way a
/// coach would, using double progression on a 3 × 6–8 rep scheme.
///
/// Business rules (applied to the most recent session since the goal was set):
/// - No sessions yet: start at 75% of the goal's starting estimated max,
///   rounded down to a loadable weight, aiming for 6 reps.
/// - Every working set hit 8 reps: add the lift's increment, aim for 6 reps.
/// - Every working set hit at least 6: same weight, one more rep than the lowest set.
/// - A missed session (any set under 6 reps): same weight, aim for 6.
/// - Two missed sessions in a row at the same weight: deload to 90%.
///
/// The prescription is derived from logged history rather than stored, so it
/// can never drift out of sync with what the lifter actually did.
@MainActor
struct PrescribeNextSessionUseCase {
    private let repository: TrainingLogRepository

    init(repository: TrainingLogRepository) {
        self.repository = repository
    }

    func execute(for goal: LiftGoal) throws -> SessionPrescription {
        guard goal.isActive else {
            throw PrescribeNextSessionError.goalAlreadyAchieved
        }

        let exercise: Exercise?
        let sets: [ExerciseSet]
        do {
            exercise = try repository.fetchExercise(id: goal.exerciseID)
            sets = try repository.fetchCompletedSets(for: goal.exerciseID, since: goal.setAt)
        } catch {
            throw PrescribeNextSessionError.historyUnavailable
        }

        guard let exercise else {
            throw PrescribeNextSessionError.liftNotFound
        }

        let history = LiftHistory.sessionRecords(from: sets)
        return Self.prescription(for: goal, exercise: exercise, history: history)
    }

    /// The progression rule itself, kept free of storage so it is easy to test.
    static func prescription(
        for goal: LiftGoal,
        exercise: Exercise,
        history: [LiftSessionRecord]
    ) -> SessionPrescription {
        guard let lastSession = history.last else {
            let startingWeight = PlateCalculator.roundDownToLoadable(
                goal.startingEstimatedMaxKg * ProgressionRules.startingIntensity
            )
            return SessionPrescription(
                exerciseID: goal.exerciseID,
                weightKg: startingWeight,
                sets: ProgressionRules.workingSets,
                targetReps: ProgressionRules.minimumReps,
                decision: .startingWeight
            )
        }

        let workingWeight = lastSession.workingWeightKg

        switch lastSession.outcome {
        case .reachedTopOfRange:
            return SessionPrescription(
                exerciseID: goal.exerciseID,
                weightKg: workingWeight + exercise.progressionIncrementKg,
                sets: ProgressionRules.workingSets,
                targetReps: ProgressionRules.minimumReps,
                decision: .addWeight(increaseKg: exercise.progressionIncrementKg)
            )

        case .withinRange(let lowestReps):
            return SessionPrescription(
                exerciseID: goal.exerciseID,
                weightKg: workingWeight,
                sets: ProgressionRules.workingSets,
                targetReps: min(ProgressionRules.maximumReps, lowestReps + 1),
                decision: .addReps
            )

        case .missed:
            if missedTwiceInARow(history: history, atWeight: workingWeight) {
                var deloadWeight = PlateCalculator.roundDownToLoadable(workingWeight * ProgressionRules.deloadFactor)
                if deloadWeight >= workingWeight {
                    deloadWeight = max(
                        PlateCalculator.standardBarWeightKg,
                        workingWeight - PlateCalculator.smallestTotalIncrementKg
                    )
                }
                return SessionPrescription(
                    exerciseID: goal.exerciseID,
                    weightKg: deloadWeight,
                    sets: ProgressionRules.workingSets,
                    targetReps: ProgressionRules.minimumReps,
                    decision: .deload(fromKg: workingWeight)
                )
            }
            return SessionPrescription(
                exerciseID: goal.exerciseID,
                weightKg: workingWeight,
                sets: ProgressionRules.workingSets,
                targetReps: ProgressionRules.minimumReps,
                decision: .repeatAfterMissedSession
            )
        }
    }

    private static func missedTwiceInARow(history: [LiftSessionRecord], atWeight weight: Double) -> Bool {
        let recent = history.suffix(ProgressionRules.consecutiveMissesBeforeDeload)
        guard recent.count == ProgressionRules.consecutiveMissesBeforeDeload else { return false }
        return recent.allSatisfy { record in
            record.outcome.isMissed && abs(record.workingWeightKg - weight) < 0.001
        }
    }
}

enum PrescribeNextSessionError: LocalizedError {
    case goalAlreadyAchieved
    case liftNotFound
    case historyUnavailable

    var errorDescription: String? {
        switch self {
        case .goalAlreadyAchieved:
            return "You've already reached this goal. Set a new target to get your next session's plan."
        case .liftNotFound:
            return "We couldn't find the lift for this goal. Try setting the goal again."
        case .historyUnavailable:
            return "Your training history couldn't be loaded, so we can't plan your next session yet. Please try again."
        }
    }
}
