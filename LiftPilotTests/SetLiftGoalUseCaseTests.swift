//  SetLiftGoalUseCaseTests.swift
//  Target membership: LiftPilotTests

import XCTest
@testable import LiftPilot

@MainActor
final class SetLiftGoalUseCaseTests: XCTestCase {
    private func makeSUT() -> (useCase: SetLiftGoalUseCase, repository: MockTrainingLogRepository) {
        let repository = MockTrainingLogRepository()
        repository.exercises = [TrainingFixtures.benchPress, TrainingFixtures.latPulldown]
        return (SetLiftGoalUseCase(repository: repository), repository)
    }

    func test_benchGoalIsSaved_withPlannedCompletionInTheFuture() throws {
        let (useCase, repository) = makeSUT()

        // 80 kg × 5 gives an estimated max of about 93.3 kg; 102.5 kg is above it.
        let goal = try useCase.execute(
            exerciseID: TrainingFixtures.benchPress.id,
            targetWeightKg: 102.5,
            referenceWeightKg: 80,
            referenceReps: 5,
            sessionsPerWeek: 2,
            now: TrainingFixtures.now
        )

        XCTAssertEqual(goal.startingEstimatedMaxKg, 93.33, accuracy: 0.01)
        XCTAssertTrue(goal.isActive)
        XCTAssertGreaterThan(goal.plannedCompletionDate, TrainingFixtures.now)
        XCTAssertEqual(repository.goals.count, 1)
    }

    func test_goalIsRejected_whenTargetIsNotAboveCurrentEstimatedMax() {
        let (useCase, repository) = makeSUT()

        // 100 kg × 3 gives an estimated max of 110 kg, already above 102.5 kg.
        XCTAssertThrowsError(try useCase.execute(
            exerciseID: TrainingFixtures.benchPress.id,
            targetWeightKg: 102.5,
            referenceWeightKg: 100,
            referenceReps: 3,
            sessionsPerWeek: 2
        )) { error in
            guard case SetLiftGoalError.targetNotAboveCurrentMax(let current) = error else {
                return XCTFail("Expected targetNotAboveCurrentMax, got \(error)")
            }
            XCTAssertEqual(current, 110, accuracy: 0.01)
        }
        XCTAssertTrue(repository.goals.isEmpty)
    }

    func test_tenRepReferenceSetIsAccepted_butElevenRepsIsRejected() {
        let (useCase, _) = makeSUT()

        // Boundary: 10 reps is the most the estimate allows.
        XCTAssertNoThrow(try useCase.execute(
            exerciseID: TrainingFixtures.benchPress.id,
            targetWeightKg: 100,
            referenceWeightKg: 60,
            referenceReps: 10,
            sessionsPerWeek: 2
        ))

        XCTAssertThrowsError(try useCase.execute(
            exerciseID: TrainingFixtures.benchPress.id,
            targetWeightKg: 100,
            referenceWeightKg: 60,
            referenceReps: 11,
            sessionsPerWeek: 2,
            replacingExistingGoal: true
        )) { error in
            guard case SetLiftGoalError.referenceRepsOutOfRange(let reps) = error else {
                return XCTFail("Expected referenceRepsOutOfRange, got \(error)")
            }
            XCTAssertEqual(reps, 11)
        }
    }

    func test_goalIsRejected_forAccessoryExercise() {
        let (useCase, _) = makeSUT()

        XCTAssertThrowsError(try useCase.execute(
            exerciseID: TrainingFixtures.latPulldown.id,
            targetWeightKg: 90,
            referenceWeightKg: 60,
            referenceReps: 8,
            sessionsPerWeek: 2
        )) { error in
            guard case SetLiftGoalError.notAMainBarbellLift = error else {
                return XCTFail("Expected notAMainBarbellLift, got \(error)")
            }
        }
    }

    func test_secondGoalOnSameLiftIsRejected_unlessReplacingTheFirst() throws {
        let (useCase, repository) = makeSUT()
        try useCase.execute(
            exerciseID: TrainingFixtures.benchPress.id,
            targetWeightKg: 102.5,
            referenceWeightKg: 80,
            referenceReps: 5,
            sessionsPerWeek: 2
        )

        XCTAssertThrowsError(try useCase.execute(
            exerciseID: TrainingFixtures.benchPress.id,
            targetWeightKg: 110,
            referenceWeightKg: 80,
            referenceReps: 5,
            sessionsPerWeek: 2
        )) { error in
            guard case SetLiftGoalError.goalAlreadyActive = error else {
                return XCTFail("Expected goalAlreadyActive, got \(error)")
            }
        }

        let replacement = try useCase.execute(
            exerciseID: TrainingFixtures.benchPress.id,
            targetWeightKg: 110,
            referenceWeightKg: 80,
            referenceReps: 5,
            sessionsPerWeek: 3,
            replacingExistingGoal: true
        )
        XCTAssertEqual(repository.goals.count, 1)
        XCTAssertEqual(replacement.targetWeightKg, 110, accuracy: 0.001)
    }
}
