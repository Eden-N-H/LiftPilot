//  StartWorkoutSessionUseCaseTests.swift
//  Target membership: LiftPilotTests

import XCTest
@testable import LiftPilot

@MainActor
final class StartWorkoutSessionUseCaseTests: XCTestCase {
    private func makeSUT() -> (useCase: StartWorkoutSessionUseCase, repository: MockTrainingLogRepository) {
        let repository = MockTrainingLogRepository()
        repository.exercises = [TrainingFixtures.benchPress]
        return (StartWorkoutSessionUseCase(repository: repository), repository)
    }

    func test_newWorkoutIsStarted_whenNoWorkoutIsInProgress() throws {
        let (useCase, repository) = makeSUT()

        let session = try useCase.execute(now: TrainingFixtures.now)

        XCTAssertTrue(session.isInProgress)
        XCTAssertEqual(repository.sessions.count, 1)
    }

    func test_existingWorkoutIsResumed_insteadOfStartingASecondOne() throws {
        let (useCase, repository) = makeSUT()
        let first = try useCase.execute(now: TrainingFixtures.daysAgo(0))

        let second = try useCase.execute(now: TrainingFixtures.daysFromNow(0))

        // Only one workout can be in progress, so the same session comes back.
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(repository.sessions.count, 1)
    }

    func test_startingFails_whenTrainingLogCannotBeLoaded() {
        let (useCase, repository) = makeSUT()
        repository.shouldFailFetches = true

        XCTAssertThrowsError(try useCase.execute(now: TrainingFixtures.now)) { error in
            guard case StartWorkoutSessionError.couldNotStartWorkout = error else {
                return XCTFail("Expected couldNotStartWorkout, got \(error)")
            }
        }
    }
}
