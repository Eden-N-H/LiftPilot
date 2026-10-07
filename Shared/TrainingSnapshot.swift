//  TrainingSnapshot.swift
//  Target membership: LiftPilot, LiftPilotWidget, RestNotificationContent

import Foundation

/// A small, read-only summary of the lifter's training state that the main app
/// writes to the App Group container after every relevant change. The widget
/// reads this instead of opening the Core Data store itself.
nonisolated struct TrainingSnapshot: Codable, Sendable {
    var generatedAt: Date
    var workoutInProgress: Bool
    var restEndsAt: Date?
    var upNext: UpNextSet?
    var featuredGoal: GoalSnapshot?
}

/// The next set the lifter is about to perform.
nonisolated struct UpNextSet: Codable, Sendable {
    var exerciseName: String
    var setLabel: String
    var weightKg: Double
    var reps: Int

    var summary: String {
        "\(WeightFormatting.kg(weightKg)) × \(reps)"
    }
}

/// The lifter's main goal lift and what their next session asks of them.
nonisolated struct GoalSnapshot: Codable, Sendable {
    var liftName: String
    var targetWeightKg: Double
    var estimatedMaxKg: Double
    var nextSessionWeightKg: Double
    var nextSessionSets: Int
    var nextSessionReps: Int
    var forecastLine: String

    var progressFraction: Double {
        guard targetWeightKg > 0 else { return 0 }
        return min(1, max(0, estimatedMaxKg / targetWeightKg))
    }

    var nextSessionSummary: String {
        "\(nextSessionSets) × \(nextSessionReps) @ \(WeightFormatting.kg(nextSessionWeightKg))"
    }
}

extension TrainingSnapshot {
    /// Sample content shown in the widget gallery before any real data exists.
    nonisolated static var preview: TrainingSnapshot {
        TrainingSnapshot(
            generatedAt: Date(),
            workoutInProgress: false,
            restEndsAt: nil,
            upNext: UpNextSet(exerciseName: "Bench Press", setLabel: "Set 2 of 3", weightKg: 82.5, reps: 7),
            featuredGoal: GoalSnapshot(
                liftName: "Bench Press",
                targetWeightKg: 102.5,
                estimatedMaxKg: 88,
                nextSessionWeightKg: 72.5,
                nextSessionSets: 3,
                nextSessionReps: 7,
                forecastLine: "On track for March"
            )
        )
    }
}

/// Reads and writes the snapshot file in the App Group container.
nonisolated enum TrainingSnapshotStore {
    static let fileName = "training-snapshot.json"

    static var fileURL: URL? {
        LiftPilotAppGroup.containerURL?.appendingPathComponent(fileName)
    }

    static func load() -> TrainingSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TrainingSnapshot.self, from: data)
    }

    static func save(_ snapshot: TrainingSnapshot) throws {
        guard let url = fileURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }
}
