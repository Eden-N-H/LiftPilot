//  LogWorkingSetUseCaseTests.swift
//  Target membership: LiftPilotTests

import XCTest
@testable import LiftPilot

@MainActor
final class LogWorkingSetUseCaseTests: XCTestCase {
    /// A workout in progress, with bench press and lat pulldown available.
    private func makeSUT() throws -> (useCase: LogWorkingSetUseCase, repository: MockTrainingLogRepository, session: WorkoutSession) {
        let repository = MockTrainingLogRepository()
        repository.exercises = [TrainingFixtures.benchPress, TrainingFixtures.latPulldown]
        let session = try repository.startSession(at: TrainingFixtures.now)
        return (LogWorkingSetUseCase(repository: repository), repository, session)
    }

    func test_barbellSetIsLogged_whenWeightCanBeLoadedWithStandardPlates() throws {
        let (useCase, repository, session) = try makeSUT()

        let set = try useCase.execute(
            sessionID: session.id,
            exerciseID: TrainingFixtures.benchPress.id,
            weightKg: 82.5,
            reps: 7
        )

        XCTAssertEqual(set.weightKg, 82.5, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchSession(id: session.id)?.sets.count, 1)
    }

    func test_barbellSetIsRejected_whenWeightCannotBeLoaded_andNearestWeightsAreSuggested() throws {
        let (useCase, _, session) = try makeSUT()

        XCTAssertThrowsError(try useCase.execute(
            sessionID: session.id,
            exerciseID: TrainingFixtures.benchPress.id,
            weightKg: 81,
            reps: 5
        )) { error in
            guard case LogWorkingSetError.weightNotLoadable(_, let lower, let upper) = error else {
                return XCTFail("Expected weightNotLoadable, got \(error)")
            }
            XCTAssertEqual(lower, 80, accuracy: 0.001)
            XCTAssertEqual(upper, 82.5, accuracy: 0.001)
        }
    }

    func test_setIsRejected_whenWorkoutHasAlreadyBeenFinished() throws {
        let (useCase, repository, session) = try makeSUT()
        try repository.markSessionFinished(id: session.id, at: TrainingFixtures.now)

        XCTAssertThrowsError(try useCase.execute(
            sessionID: session.id,
            exerciseID: TrainingFixtures.benchPress.id,
            weightKg: 80,
            reps: 5
        )) { error in
            guard case LogWorkingSetError.workoutAlreadyFinished = error else {
                return XCTFail("Expected workoutAlreadyFinished, got \(error)")
            }
        }
    }

    func test_zeroRepsIsRejected_butBodyweightAccessorySetAtZeroKgIsAccepted() throws {
        let (useCase, _, session) = try makeSUT()

        XCTAssertThrowsError(try useCase.execute(
            sessionID: session.id,
            exerciseID: TrainingFixtures.benchPress.id,
            weightKg: 80,
            reps: 0
        )) { error in
            guard case LogWorkingSetError.repsOutOfRange = error else {
                return XCTFail("Expected repsOutOfRange, got \(error)")
            }
        }

        XCTAssertNoThrow(try useCase.execute(
            sessionID: session.id,
            exerciseID: TrainingFixtures.latPulldown.id,
            weightKg: 0,
            reps: 10
        ))
    }
}
