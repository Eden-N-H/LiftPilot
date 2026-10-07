//  TrainingLogRepository.swift

import Foundation

/// The persistence operations LiftPilot's use cases depend on. Views and view
/// models never touch Core Data; they go through this protocol, which also lets
/// unit tests swap in an in-memory mock.
@MainActor
protocol TrainingLogRepository {
    // MARK: Exercises
    func fetchExercises() throws -> [Exercise]
    func fetchExercise(id: UUID) throws -> Exercise?

    // MARK: Workout sessions
    func fetchInProgressSession() throws -> WorkoutSession?
    func fetchSession(id: UUID) throws -> WorkoutSession?
    func fetchRecentCompletedSessions(limit: Int) throws -> [WorkoutSession]
    @discardableResult
    func startSession(at date: Date) throws -> WorkoutSession
    func markSessionFinished(id: UUID, at date: Date) throws
    func deleteSession(id: UUID) throws

    // MARK: Sets
    @discardableResult
    func addSet(_ set: ExerciseSet) throws -> ExerciseSet
    func deleteSet(id: UUID) throws
    /// Sets of one exercise from finished workouts that started on or after `date`.
    func fetchCompletedSets(for exerciseID: UUID, since date: Date?) throws -> [ExerciseSet]

    // MARK: Lift goals
    func fetchActiveGoals() throws -> [LiftGoal]
    func fetchActiveGoal(for exerciseID: UUID) throws -> LiftGoal?
    func saveGoal(_ goal: LiftGoal) throws
}

/// Technical storage failures. Use cases translate these into messages written
/// for the lifter rather than showing them directly.
enum RepositoryError: LocalizedError {
    case recordNotFound
    case saveFailed(String)
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .recordNotFound:
            return "The record could not be found."
        case .saveFailed(let detail):
            return "Saving failed: \(detail)"
        case .fetchFailed(let detail):
            return "Loading failed: \(detail)"
        }
    }
}
