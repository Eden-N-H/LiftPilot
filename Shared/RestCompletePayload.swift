//  RestCompletePayload.swift
//  Target membership: LiftPilot, LiftPilotWidget, RestNotificationContent

import Foundation

/// Everything the "rest over" notification needs to show the lifter how to load
/// the bar for their next set. The main app does the calculations; the
/// notification content extension only displays the result.
nonisolated struct RestCompletePayload: Codable, Sendable {
    static let categoryIdentifier = "REST_COMPLETE"
    static let userInfoKey = "restCompletePayload"

    var exerciseName: String
    var setLabel: String
    var weightKg: Double
    var reps: Int
    /// nil when the exercise isn't loaded on a standard barbell.
    var barWeightKg: Double?
    var platesPerSideKg: [Double]
    var lastSessionLine: String?
    var goalLine: String?
    var goalProgress: Double?

    var userInfo: [AnyHashable: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return [:]
        }
        return [Self.userInfoKey: json]
    }

    init(
        exerciseName: String,
        setLabel: String,
        weightKg: Double,
        reps: Int,
        barWeightKg: Double?,
        platesPerSideKg: [Double],
        lastSessionLine: String?,
        goalLine: String?,
        goalProgress: Double?
    ) {
        self.exerciseName = exerciseName
        self.setLabel = setLabel
        self.weightKg = weightKg
        self.reps = reps
        self.barWeightKg = barWeightKg
        self.platesPerSideKg = platesPerSideKg
        self.lastSessionLine = lastSessionLine
        self.goalLine = goalLine
        self.goalProgress = goalProgress
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let json = userInfo[Self.userInfoKey] as? String,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(RestCompletePayload.self, from: data) else {
            return nil
        }
        self = decoded
    }
}
