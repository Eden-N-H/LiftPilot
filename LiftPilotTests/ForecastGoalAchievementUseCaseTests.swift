//  ForecastGoalAchievementUseCaseTests.swift
//  Target membership: LiftPilotTests

import XCTest
@testable import LiftPilot

@MainActor
final class ForecastGoalAchievementUseCaseTests: XCTestCase {
    private func makeSUT(goal: LiftGoal) -> (useCase: ForecastGoalAchievementUseCase, repository: MockTrainingLogRepository) {
        let repository = MockTrainingLogRepository()
        repository.exercises = [TrainingFixtures.benchPress]
        repository.goals = [goal]
        return (ForecastGoalAchievementUseCase(repository: repository), repository)
    }

    /// Logs one single-rep set per session, so each session's estimated max
    /// is exactly the weight lifted.
    private func logSingles(_ sessions: [(daysAgo: Int, weightKg: Double)], repository: MockTrainingLogRepository) {
        for session in sessions {
            repository.addCompletedSession(
                on: TrainingFixtures.daysAgo(session.daysAgo),
                exercise: TrainingFixtures.benchPress,
                sets: [(session.weightKg, 1)]
            )
        }
    }

    func test_noForecastDate_withFewerThanFourSessions() throws {
        let goal = TrainingFixtures.benchGoal(startingEstimatedMaxKg: 85)
        let (useCase, repository) = makeSUT(goal: goal)
        logSingles([(21, 86), (14, 88), (7, 90)], repository: repository)

        let forecast = try useCase.execute(for: goal, asOf: TrainingFixtures.now)

        guard case .notEnoughData(let logged, let needed, _) = forecast.status else {
            return XCTFail("Expected notEnoughData, got \(forecast.status)")
        }
        XCTAssertEqual(logged, 3)
        XCTAssertEqual(needed, 4)
        XCTAssertNil(forecast.forecastDate)
    }

    func test_liftIsStalled_whenEstimatedMaxIsFlatAcrossRecentSessions() throws {
        let goal = TrainingFixtures.benchGoal(startingEstimatedMaxKg: 85)
        let (useCase, repository) = makeSUT(goal: goal)
        logSingles([(28, 90), (21, 90), (14, 90), (7, 90)], repository: repository)

        let forecast = try useCase.execute(for: goal, asOf: TrainingFixtures.now)

        guard case .stalled = forecast.status else {
            return XCTFail("Expected stalled, got \(forecast.status)")
        }
        XCTAssertNil(forecast.forecastDate)
    }

    func test_forecastIsAheadOfPlan_whenLifterIsGainingFasterThanPlanned() throws {
        // Gaining 2 kg a week from 86 kg to 94 kg; 8.5 kg to go is about 30 days.
        // The plan says 60 days, so the lifter is roughly 30 days ahead.
        let goal = TrainingFixtures.benchGoal(
            targetKg: 102.5,
            startingEstimatedMaxKg: 85,
            plannedCompletionDate: TrainingFixtures.daysFromNow(60)
        )
        let (useCase, repository) = makeSUT(goal: goal)
        logSingles([(28, 86), (21, 88), (14, 90), (7, 92), (0, 94)], repository: repository)

        let forecast = try useCase.execute(for: goal, asOf: TrainingFixtures.now)

        guard case .aheadOfPlan(let forecastDate, let daysAhead) = forecast.status else {
            return XCTFail("Expected aheadOfPlan, got \(forecast.status)")
        }
        XCTAssertTrue((29...31).contains(daysAhead), "Expected about 30 days ahead, got \(daysAhead)")
        XCTAssertGreaterThan(forecastDate, TrainingFixtures.now)
        XCTAssertEqual(forecast.currentEstimatedMaxKg, 94, accuracy: 0.001)
    }

    func test_goalIsReadyToTest_whenEstimatedMaxReachesTarget() throws {
        // 95 kg × 3 estimates a 104.5 kg max, above the 102.5 kg target.
        let goal = TrainingFixtures.benchGoal(targetKg: 102.5, startingEstimatedMaxKg: 85)
        let (useCase, repository) = makeSUT(goal: goal)
        repository.addCompletedSession(
            on: TrainingFixtures.daysAgo(2),
            exercise: TrainingFixtures.benchPress,
            sets: [(95, 3)]
        )

        let forecast = try useCase.execute(for: goal, asOf: TrainingFixtures.now)

        guard case .readyToTest = forecast.status else {
            return XCTFail("Expected readyToTest, got \(forecast.status)")
        }
        XCTAssertEqual(forecast.progressFraction, 1, accuracy: 0.001)
    }
}
