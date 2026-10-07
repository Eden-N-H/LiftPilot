//  SetLiftGoalUseCase.swift

import Foundation

/// Commits the lifter to a target weight on a main barbell lift and works out
/// the planned timeline for reaching it.
///
/// Business rules:
/// - Goals can only be set on the main barbell lifts.
/// - Each lift has at most one active goal (unless the lifter chooses to replace it).
/// - The reference set must be 1–10 reps at a weight above zero, so the
///   starting estimated max is trustworthy.
/// - The target must be above the current estimated max, and no more than
///   double it (which catches typos and unrealistic goals).
/// - Training frequency must be 1–4 sessions per week for that lift.
@MainActor
struct SetLiftGoalUseCase {
    static let allowedSessionsPerWeek = 1...4
    static let maximumTargetMultiple = 2.0

    private let repository: TrainingLogRepository

    init(repository: TrainingLogRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute(
        exerciseID: UUID,
        targetWeightKg: Double,
        referenceWeightKg: Double,
        referenceReps: Int,
        sessionsPerWeek: Int,
        replacingExistingGoal: Bool = false,
        now: Date = Date()
    ) throws -> LiftGoal {
        let exercise: Exercise
        do {
            guard let found = try repository.fetchExercise(id: exerciseID) else {
                throw SetLiftGoalError.liftNotFound
            }
            exercise = found
        } catch let error as SetLiftGoalError {
            throw error
        } catch {
            throw SetLiftGoalError.persistenceFailed
        }

        guard exercise.isMainBarbellLift else {
            throw SetLiftGoalError.notAMainBarbellLift(exerciseName: exercise.name)
        }

        guard referenceWeightKg > 0 else {
            throw SetLiftGoalError.invalidReferenceWeight
        }

        guard let startingEstimatedMax = OneRepMaxEstimator.estimatedMaxKg(
            weightKg: referenceWeightKg,
            reps: referenceReps
        ) else {
            throw SetLiftGoalError.referenceRepsOutOfRange(reps: referenceReps)
        }

        guard Self.allowedSessionsPerWeek.contains(sessionsPerWeek) else {
            throw SetLiftGoalError.invalidTrainingFrequency
        }

        guard targetWeightKg > startingEstimatedMax else {
            throw SetLiftGoalError.targetNotAboveCurrentMax(currentEstimatedMaxKg: startingEstimatedMax)
        }

        guard targetWeightKg <= startingEstimatedMax * Self.maximumTargetMultiple else {
            throw SetLiftGoalError.targetUnrealistic(currentEstimatedMaxKg: startingEstimatedMax)
        }

        let existingGoal: LiftGoal?
        do {
            existingGoal = try repository.fetchActiveGoal(for: exerciseID)
        } catch {
            throw SetLiftGoalError.persistenceFailed
        }
        if existingGoal != nil && !replacingExistingGoal {
            throw SetLiftGoalError.goalAlreadyActive(exerciseName: exercise.name)
        }

        let startingWeight = PlateCalculator.roundDownToLoadable(
            startingEstimatedMax * ProgressionRules.startingIntensity
        )
        let plannedDate = GoalTimelinePlanner.plannedCompletionDate(
            startingWeightKg: startingWeight,
            incrementKg: exercise.progressionIncrementKg,
            targetWeightKg: targetWeightKg,
            sessionsPerWeek: sessionsPerWeek,
            from: now
        )

        let goal = LiftGoal(
            id: existingGoal?.id ?? UUID(),
            exerciseID: exerciseID,
            targetWeightKg: targetWeightKg,
            startingEstimatedMaxKg: startingEstimatedMax,
            sessionsPerWeek: sessionsPerWeek,
            setAt: now,
            plannedCompletionDate: plannedDate,
            status: .active,
            achievedAt: nil
        )

        do {
            try repository.saveGoal(goal)
        } catch {
            throw SetLiftGoalError.persistenceFailed
        }
        return goal
    }
}

enum SetLiftGoalError: LocalizedError {
    case liftNotFound
    case notAMainBarbellLift(exerciseName: String)
    case invalidReferenceWeight
    case referenceRepsOutOfRange(reps: Int)
    case invalidTrainingFrequency
    case targetNotAboveCurrentMax(currentEstimatedMaxKg: Double)
    case targetUnrealistic(currentEstimatedMaxKg: Double)
    case goalAlreadyActive(exerciseName: String)
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .liftNotFound:
            return "We couldn't find that lift. Go back and choose a lift from the list."
        case .notAMainBarbellLift(let name):
            return "Goals can be set on bench press, squat, deadlift and overhead press. \(name) is logged, but not coached towards a goal."
        case .invalidReferenceWeight:
            return "Enter the weight of a recent set you're proud of, so we know where you're starting from."
        case .referenceRepsOutOfRange(let reps):
            return "Use a recent set of 1 to 10 reps. Estimates from a \(reps)-rep set aren't reliable enough to plan from."
        case .invalidTrainingFrequency:
            return "Choose how often you train this lift: between 1 and 4 sessions a week."
        case .targetNotAboveCurrentMax(let current):
            return "Your estimated max is already about \(WeightFormatting.kg(current)). Set a target above that so there's something to work towards."
        case .targetUnrealistic(let current):
            return "That target is more than double your estimated max of \(WeightFormatting.kg(current)). Check for a typo, or set a nearer goal first."
        case .goalAlreadyActive(let name):
            return "You already have an active \(name) goal. Open that lift and choose Change goal to replace it."
        case .persistenceFailed:
            return "Your goal couldn't be saved. Please try again."
        }
    }
}
