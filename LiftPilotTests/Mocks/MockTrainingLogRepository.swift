//  MockTrainingLogRepository.swift
//  Target membership: LiftPilotTests

import Foundation
@testable import LiftPilot

/// In-memory training log used by every unit test instead of Core Data.
@MainActor
final class MockTrainingLogRepository: TrainingLogRepository {
    var exercises: [Exercise] = []
    var sessions: [WorkoutSession] = []
    var goals: [LiftGoal] = []
    /// When true, every fetch throws, to test how use cases handle storage failures.
    var shouldFailFetches = false

    // MARK: Exercises

    func fetchExercises() throws -> [Exercise] {
        try failIfNeeded()
        return exercises
    }

    func fetchExercise(id: UUID) throws -> Exercise? {
        try failIfNeeded()
        return exercises.first { $0.id == id }
    }

    // MARK: Sessions

    func fetchInProgressSession() throws -> WorkoutSession? {
        try failIfNeeded()
        return sessions.last { $0.isInProgress }
    }

    func fetchSession(id: UUID) throws -> WorkoutSession? {
        try failIfNeeded()
        return sessions.first { $0.id == id }
    }

    func fetchRecentCompletedSessions(limit: Int) throws -> [WorkoutSession] {
        try failIfNeeded()
        return Array(sessions.filter { !$0.isInProgress }.sorted { $0.startedAt > $1.startedAt }.prefix(limit))
    }

    @discardableResult
    func startSession(at date: Date) throws -> WorkoutSession {
        let session = WorkoutSession(id: UUID(), startedAt: date, finishedAt: nil, sets: [])
        sessions.append(session)
        return session
    }

    func markSessionFinished(id: UUID, at date: Date) throws {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.recordNotFound
        }
        sessions[index].finishedAt = date
    }

    func deleteSession(id: UUID) throws {
        sessions.removeAll { $0.id == id }
    }

    // MARK: Sets

    @discardableResult
    func addSet(_ set: ExerciseSet) throws -> ExerciseSet {
        guard let index = sessions.firstIndex(where: { $0.id == set.sessionID }) else {
            throw RepositoryError.recordNotFound
        }
        sessions[index].sets.append(set)
        return set
    }

    func deleteSet(id: UUID) throws {
        for index in sessions.indices {
            sessions[index].sets.removeAll { $0.id == id }
        }
    }

    func fetchCompletedSets(for exerciseID: UUID, since date: Date?) throws -> [ExerciseSet] {
        try failIfNeeded()
        return sessions
            .filter { !$0.isInProgress && $0.startedAt >= (date ?? .distantPast) }
            .flatMap { $0.sets(for: exerciseID) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    // MARK: Goals

    func fetchActiveGoals() throws -> [LiftGoal] {
        try failIfNeeded()
        return goals.filter(\.isActive)
    }

    func fetchActiveGoal(for exerciseID: UUID) throws -> LiftGoal? {
        try failIfNeeded()
        return goals.first { $0.exerciseID == exerciseID && $0.isActive }
    }

    func saveGoal(_ goal: LiftGoal) throws {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
        } else {
            goals.append(goal)
        }
    }

    // MARK: Test helpers

    private func failIfNeeded() throws {
        if shouldFailFetches {
            throw RepositoryError.fetchFailed("Simulated failure")
        }
    }

    /// Adds a finished workout containing the given (weight, reps) sets for one exercise.
    @discardableResult
    func addCompletedSession(
        on date: Date,
        exercise: Exercise,
        sets: [(weightKg: Double, reps: Int)]
    ) -> WorkoutSession {
        let sessionID = UUID()
        let loggedSets = sets.enumerated().map { index, set in
            ExerciseSet(
                id: UUID(),
                sessionID: sessionID,
                exerciseID: exercise.id,
                weightKg: set.weightKg,
                reps: set.reps,
                loggedAt: date.addingTimeInterval(Double(index) * 180)
            )
        }
        let session = WorkoutSession(
            id: sessionID,
            startedAt: date,
            finishedAt: date.addingTimeInterval(3_600),
            sets: loggedSets
        )
        sessions.append(session)
        return session
    }
}
