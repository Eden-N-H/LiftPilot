//  PrescribeNextSessionUseCaseTests.swift
//  Target membership: LiftPilotTests

import XCTest
@testable import LiftPilot

@MainActor
final class PrescribeNextSessionUseCaseTests: XCTestCase {
    /// A bench goal (starting estimated max 85 kg) with no training logged yet.
    private func makeSUT() -> (useCase: PrescribeNextSessionUseCase, repository: MockTrainingLogRepository, goal: LiftGoal) {
        let repository = MockTrainingLogRepository()
        repository.exercises = [TrainingFixtures.benchPress]
        let goal = TrainingFixtures.benchGoal(startingEstimatedMaxKg: 85)
        repository.goals = [goal]
        return (PrescribeNextSessionUseCase(repository: repository), repository, goal)
    }

    func test_firstSession_startsAt75PercentOfEstimatedMax_roundedDownToLoadableWeight() throws {
        let (useCase, _, goal) = makeSUT()

        // 75% of 85 kg is 63.75 kg, which can't be loaded; it rounds down to 62.5 kg.
        let prescription = try useCase.execute(for: goal)

        XCTAssertEqual(prescription.weightKg, 62.5, accuracy: 0.001)
        XCTAssertEqual(prescription.targetReps, 6)
        XCTAssertEqual(prescription.sets, 3)
        guard case .startingWeight = prescription.decision else {
            return XCTFail("Expected startingWeight, got \(prescription.decision)")
        }
    }

    func test_weightGoesUp_whenEverySetReachedEightReps() throws {
        let (useCase, repository, goal) = makeSUT()
        repository.addCompletedSession(
            on: TrainingFixtures.daysAgo(3),
            exercise: TrainingFixtures.benchPress,
            sets: [(70, 8), (70, 8), (70, 8)]
        )

        let prescription = try useCase.execute(for: goal)

        XCTAssertEqual(prescription.weightKg, 72.5, accuracy: 0.001)
        XCTAssertEqual(prescription.targetReps, 6)
        guard case .addWeight(let increase) = prescription.decision else {
            return XCTFail("Expected addWeight, got \(prescription.decision)")
        }
        XCTAssertEqual(increase, 2.5, accuracy: 0.001)
    }

    func test_sameWeightWithOneMoreRep_whenLowestSetIsExactlySixReps() throws {
        // Boundary: 6 reps is the bottom of the range and still counts as a success.
        let (useCase, repository, goal) = makeSUT()
        repository.addCompletedSession(
            on: TrainingFixtures.daysAgo(3),
            exercise: TrainingFixtures.benchPress,
            sets: [(70, 7), (70, 6), (70, 7)]
        )

        let prescription = try useCase.execute(for: goal)

        XCTAssertEqual(prescription.weightKg, 70, accuracy: 0.001)
        XCTAssertEqual(prescription.targetReps, 7)
        guard case .addReps = prescription.decision else {
            return XCTFail("Expected addReps, got \(prescription.decision)")
        }
    }

    func test_weightIsRepeated_afterOneMissedSession() throws {
        // Boundary: 5 reps on one set is one short of the range, so the session is missed.
        let (useCase, repository, goal) = makeSUT()
        repository.addCompletedSession(
            on: TrainingFixtures.daysAgo(3),
            exercise: TrainingFixtures.benchPress,
            sets: [(70, 6), (70, 6), (70, 5)]
        )

        let prescription = try useCase.execute(for: goal)

        XCTAssertEqual(prescription.weightKg, 70, accuracy: 0.001)
        XCTAssertEqual(prescription.targetReps, 6)
        guard case .repeatAfterMissedSession = prescription.decision else {
            return XCTFail("Expected repeatAfterMissedSession, got \(prescription.decision)")
        }
    }

    func test_lifterIsDeloadedToNinetyPercent_afterTwoMissedSessionsInARow() throws {
        let (useCase, repository, goal) = makeSUT()
        repository.addCompletedSession(
            on: TrainingFixtures.daysAgo(7),
            exercise: TrainingFixtures.benchPress,
            sets: [(70, 6), (70, 6), (70, 5)]
        )
        repository.addCompletedSession(
            on: TrainingFixtures.daysAgo(3),
            exercise: TrainingFixtures.benchPress,
            sets: [(70, 6), (70, 5), (70, 4)]
        )

        let prescription = try useCase.execute(for: goal)

        // 90% of 70 kg is 63 kg, rounded down to a loadable 62.5 kg.
        XCTAssertEqual(prescription.weightKg, 62.5, accuracy: 0.001)
        XCTAssertEqual(prescription.targetReps, 6)
        guard case .deload(let fromKg) = prescription.decision else {
            return XCTFail("Expected deload, got \(prescription.decision)")
        }
        XCTAssertEqual(fromKg, 70, accuracy: 0.001)
    }

    func test_noDeload_whenTheTwoMissedSessionsWereAtDifferentWeights() throws {
        let (useCase, repository, goal) = makeSUT()
        repository.addCompletedSession(
            on: TrainingFixtures.daysAgo(7),
            exercise: TrainingFixtures.benchPress,
            sets: [(67.5, 6), (67.5, 6), (67.5, 5)]
        )
        repository.addCompletedSession(
            on: TrainingFixtures.daysAgo(3),
            exercise: TrainingFixtures.benchPress,
            sets: [(70, 6), (70, 5), (70, 5)]
        )

        let prescription = try useCase.execute(for: goal)

        guard case .repeatAfterMissedSession = prescription.decision else {
            return XCTFail("Expected repeatAfterMissedSession, got \(prescription.decision)")
        }
        XCTAssertEqual(prescription.weightKg, 70, accuracy: 0.001)
    }

    func test_prescriptionFails_whenGoalHasAlreadyBeenAchieved() {
        let (useCase, _, activeGoal) = makeSUT()
        var achievedGoal = activeGoal
        achievedGoal.status = .achieved

        XCTAssertThrowsError(try useCase.execute(for: achievedGoal)) { error in
            guard case PrescribeNextSessionError.goalAlreadyAchieved = error else {
                return XCTFail("Expected goalAlreadyAchieved, got \(error)")
            }
        }
    }

    func test_prescriptionFails_whenTrainingHistoryCannotBeLoaded() {
        let (useCase, repository, goal) = makeSUT()
        repository.shouldFailFetches = true

        XCTAssertThrowsError(try useCase.execute(for: goal)) { error in
            guard case PrescribeNextSessionError.historyUnavailable = error else {
                return XCTFail("Expected historyUnavailable, got \(error)")
            }
        }
    }
}
