//  LogWorkingSetUseCase.swift

import Foundation

/// Records a set the lifter has just performed.
///
/// Business rules:
/// - Sets can only be added to a workout that is still in progress.
/// - Reps must be between 1 and 30.
/// - Main barbell lifts must use a weight that can actually be loaded on a
///   20 kg bar with standard plates (e.g. 82.5 kg, not 81 kg).
/// - Accessory weights can't be negative (0 kg is allowed for bodyweight moves).
@MainActor
struct LogWorkingSetUseCase {
    static let allowedReps = 1...30

    private let repository: TrainingLogRepository

    init(repository: TrainingLogRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute(
        sessionID: UUID,
        exerciseID: UUID,
        weightKg: Double,
        reps: Int,
        loggedAt: Date = Date()
    ) throws -> ExerciseSet {
        let session: WorkoutSession?
        let exercise: Exercise?
        do {
            session = try repository.fetchSession(id: sessionID)
            exercise = try repository.fetchExercise(id: exerciseID)
        } catch {
            throw LogWorkingSetError.persistenceFailed
        }

        guard let session, session.isInProgress else {
            throw LogWorkingSetError.workoutAlreadyFinished
        }
        guard let exercise else {
            throw LogWorkingSetError.exerciseNotFound
        }

        guard Self.allowedReps.contains(reps) else {
            throw LogWorkingSetError.repsOutOfRange
        }

        if exercise.isMainBarbellLift {
            guard weightKg >= PlateCalculator.standardBarWeightKg else {
                throw LogWorkingSetError.lighterThanEmptyBar
            }
            guard PlateCalculator.isLoadable(weightKg) else {
                let nearest = PlateCalculator.nearestLoadableWeights(to: weightKg)
                throw LogWorkingSetError.weightNotLoadable(
                    requestedKg: weightKg,
                    lowerKg: nearest.lower,
                    upperKg: nearest.upper
                )
            }
        } else {
            guard weightKg >= 0 else {
                throw LogWorkingSetError.negativeWeight
            }
        }

        let set = ExerciseSet(
            id: UUID(),
            sessionID: session.id,
            exerciseID: exercise.id,
            weightKg: weightKg,
            reps: reps,
            loggedAt: loggedAt
        )

        do {
            return try repository.addSet(set)
        } catch {
            throw LogWorkingSetError.persistenceFailed
        }
    }
}

enum LogWorkingSetError: LocalizedError {
    case workoutAlreadyFinished
    case exerciseNotFound
    case repsOutOfRange
    case lighterThanEmptyBar
    case weightNotLoadable(requestedKg: Double, lowerKg: Double, upperKg: Double)
    case negativeWeight
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .workoutAlreadyFinished:
            return "This workout has already been finished. Start a new workout to log more sets."
        case .exerciseNotFound:
            return "We couldn't find that exercise. Remove it and add it again from the exercise list."
        case .repsOutOfRange:
            return "Enter between 1 and 30 reps for this set."
        case .lighterThanEmptyBar:
            return "The empty bar weighs 20 kg, so a barbell set can't be lighter than that."
        case .weightNotLoadable(let requested, let lower, let upper):
            return "\(WeightFormatting.kg(requested)) can't be loaded with standard plates. Did you mean \(WeightFormatting.kg(lower)) or \(WeightFormatting.kg(upper))?"
        case .negativeWeight:
            return "Weight can't be negative. Use 0 kg for bodyweight sets."
        case .persistenceFailed:
            return "That set couldn't be saved. Please try again."
        }
    }
}
