//  StartWorkoutSessionUseCase.swift

import Foundation

/// Starts a workout, or resumes the one already in progress.
///
/// Business rule: a lifter can only have one workout in progress at a time,
/// so starting again returns the existing workout instead of creating a second.
@MainActor
struct StartWorkoutSessionUseCase {
    private let repository: TrainingLogRepository

    init(repository: TrainingLogRepository) {
        self.repository = repository
    }

    func execute(now: Date = Date()) throws -> WorkoutSession {
        do {
            if let inProgress = try repository.fetchInProgressSession() {
                return inProgress
            }
            return try repository.startSession(at: now)
        } catch {
            throw StartWorkoutSessionError.couldNotStartWorkout
        }
    }
}

enum StartWorkoutSessionError: LocalizedError {
    case couldNotStartWorkout

    var errorDescription: String? {
        switch self {
        case .couldNotStartWorkout:
            return "Your workout couldn't be started. Please try again."
        }
    }
}
