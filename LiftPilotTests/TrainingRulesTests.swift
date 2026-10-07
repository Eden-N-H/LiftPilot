//  TrainingRulesTests.swift
//  Target membership: LiftPilotTests
//
//  The domain helpers the use cases are built on.

import XCTest
@testable import LiftPilot

@MainActor
final class TrainingRulesTests: XCTestCase {
    func test_estimatedMax_ofASingleIsTheWeightLifted() {
        XCTAssertEqual(OneRepMaxEstimator.estimatedMaxKg(weightKg: 82, reps: 1) ?? 0, 82, accuracy: 0.001)
    }

    func test_estimatedMax_isUnavailableAboveTenReps() {
        XCTAssertNotNil(OneRepMaxEstimator.estimatedMaxKg(weightKg: 60, reps: 10))
        XCTAssertNil(OneRepMaxEstimator.estimatedMaxKg(weightKg: 60, reps: 11))
    }

    func test_plateBreakdown_for102point5Kg_is25Plus15Plus1point25EachSide() {
        let breakdown = PlateCalculator.breakdown(forTotalKg: 102.5)

        XCTAssertTrue(breakdown.isExact)
        XCTAssertEqual(breakdown.platesPerSideKg, [25, 15, 1.25])
    }

    func test_plannedTimeline_from62point5KgTo102point5Kg_takes27PerfectSessions() {
        // 62.5 → 80 kg is 8 weights × 3 sessions (6, 7, then 8 reps), then
        // 82.5 kg × 8 reps (estimated 104.5 kg) on the 27th session.
        let sessions = GoalTimelinePlanner.plannedSessionCount(
            startingWeightKg: 62.5,
            startingTargetReps: 6,
            incrementKg: 2.5,
            targetWeightKg: 102.5
        )

        XCTAssertEqual(sessions, 27)
    }
}
