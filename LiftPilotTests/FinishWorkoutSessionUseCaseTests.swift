//  FinishWorkoutSessionUseCaseTests.swift
//  Target membership: LiftPilotTests

import XCTest
@testable import LiftPilot

@MainActor
final class FinishWorkoutSessionUseCaseTests: XCTestCase {
    private func makeSUT(goal: LiftGoal) -> (useCase: FinishWorkoutSessionUseCase, repository: MockTrainingLogRepository) {
        let repository = MockTrainingLogRepository()
        repository.exercises = [TrainingFixtures.benchPress]
        repository.goals = [goal]
        return (FinishWorkoutSessionUseCase(repository: repository), repository)
    }

    private func logSets(
        _ sets: [(weightKg: Double, reps: Int)],
        in session: WorkoutSession,
        repository: MockTrainingLogRepository
    ) throws {
        for (index, set) in sets.enumerated() {
            try repository.addSet(ExerciseSet(
                id: UUID(),
                sessionID: session.id,
                exerciseID: TrainingFixtures.benchPress.id,
                weightKg: set.weightKg,
                reps: set.reps,
                loggedAt: session.startedAt.addingTimeInterval(Double(index) * 180)
            ))
        }
    }

    func test_finishingFails_whenNoSetsWereLogged() throws {
        let (useCase, repository) = makeSUT(goal: TrainingFixtures.benchGoal())
        let session = try repository.startSession(at: TrainingFixtures.now)

        XCTAssertThrowsError(try useCase.execute(sessionID: session.id, finishedAt: TrainingFixtures.now)) { error in
            guard case FinishWorkoutSessionError.noSetsLogged = error else {
                return XCTFail("Expected noSetsLogged, got \(error)")
            }
        }
        XCTAssertTrue(try repository.fetchSession(id: session.id)?.isInProgress ?? false)
    }

    func test_goalIsMarkedAchieved_whenTargetWeightIsLifted() throws {
        let goal = TrainingFixtures.benchGoal(targetKg: 102.5)
        let (useCase, repository) = makeSUT(goal: goal)
        let session = try repository.startSession(at: TrainingFixtures.now)
        try logSets([(90, 3), (102.5, 1)], in: session, repository: repository)

        let summary = try useCase.execute(sessionID: session.id, finishedAt: TrainingFixtures.now)

        XCTAssertEqual(summary.goalDebriefs.count, 1)
        XCTAssertTrue(summary.goalDebriefs[0].goalAchieved)
        // Compared as Bool: with main-actor default isolation, the app's own
        // Equatable conformances can't be used inside XCTAssertEqual.
        XCTAssertEqual(repository.goals.first?.isActive, false)
        XCTAssertNotNil(repository.goals.first?.achievedAt)
    }

    func test_planIsRecalculated_whenSecondMissedSessionTriggersDeload() throws {
        let goal = TrainingFixtures.benchGoal(setDaysAgo: 30, plannedCompletionDate: TrainingFixtures.daysFromNow(40))
        let (useCase, repository) = makeSUT(goal: goal)
        repository.addCompletedSession(
            on: TrainingFixtures.daysAgo(4),
            exercise: TrainingFixtures.benchPress,
            sets: [(70, 6), (70, 6), (70, 5)]
        )
        let session = try repository.startSession(at: TrainingFixtures.now)
        try logSets([(70, 6), (70, 5), (70, 4)], in: session, repository: repository)

        let summary = try useCase.execute(sessionID: session.id, finishedAt: TrainingFixtures.now)

        let debrief = try XCTUnwrap(summary.goalDebriefs.first)
        XCTAssertTrue(debrief.planWasRecalculated)
        guard case .deload = debrief.nextPrescription?.decision else {
            return XCTFail("Expected a deload prescription, got \(String(describing: debrief.nextPrescription))")
        }
        XCTAssertNotEqual(repository.goals.first?.plannedCompletionDate, TrainingFixtures.daysFromNow(40))
    }

    func test_finishingTwice_isRejected() throws {
        let (useCase, repository) = makeSUT(goal: TrainingFixtures.benchGoal())
        let session = try repository.startSession(at: TrainingFixtures.now)
        try logSets([(70, 8)], in: session, repository: repository)
        try useCase.execute(sessionID: session.id, finishedAt: TrainingFixtures.now)

        XCTAssertThrowsError(try useCase.execute(sessionID: session.id, finishedAt: TrainingFixtures.now)) { error in
            guard case FinishWorkoutSessionError.workoutAlreadyFinished = error else {
                return XCTFail("Expected workoutAlreadyFinished, got \(error)")
            }
        }
    }
}
