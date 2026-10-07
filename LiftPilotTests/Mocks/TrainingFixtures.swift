//  TrainingFixtures.swift
//  Target membership: LiftPilotTests

import Foundation
@testable import LiftPilot

/// Shared test data: realistic lifts and goals.
@MainActor
enum TrainingFixtures {
    static let benchPress = Exercise(
        id: UUID(),
        name: "Bench Press",
        category: .mainBarbellLift,
        progressionIncrementKg: 2.5
    )

    static let latPulldown = Exercise(
        id: UUID(),
        name: "Lat Pulldown",
        category: .accessory,
        progressionIncrementKg: 2.5
    )

    /// A fixed "now" (15 July 2026, midday UTC) so date-based rules are deterministic.
    static let now = Date(timeIntervalSince1970: 1_784_116_800)

    /// Exactly `days` × 24 hours before `now`, so trend maths isn't affected by
    /// daylight saving changes.
    static func daysAgo(_ days: Int) -> Date {
        now.addingTimeInterval(-Double(days) * 86_400)
    }

    static func daysFromNow(_ days: Int) -> Date {
        now.addingTimeInterval(Double(days) * 86_400)
    }

    static func benchGoal(
        targetKg: Double = 102.5,
        startingEstimatedMaxKg: Double = 85,
        setDaysAgo: Int = 60,
        plannedCompletionDate: Date? = nil
    ) -> LiftGoal {
        LiftGoal(
            id: UUID(),
            exerciseID: benchPress.id,
            targetWeightKg: targetKg,
            startingEstimatedMaxKg: startingEstimatedMaxKg,
            sessionsPerWeek: 2,
            setAt: daysAgo(setDaysAgo),
            plannedCompletionDate: plannedCompletionDate ?? daysFromNow(60),
            status: .active,
            achievedAt: nil
        )
    }
}
