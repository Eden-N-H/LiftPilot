//  TrainingPreferences.swift

import Foundation

/// Device-level preferences with no business rule attached, so they live in
/// UserDefaults (@AppStorage) rather than Core Data.
enum TrainingPreferences {
    static let restDurationKey = "restDurationSeconds"
    static let defaultRestDurationSeconds = 120
    static let restDurationOptions = [60, 90, 120, 150, 180, 240]

    static var restDurationSeconds: Int {
        let stored = UserDefaults.standard.integer(forKey: restDurationKey)
        return stored > 0 ? stored : defaultRestDurationSeconds
    }

    static func restDurationLabel(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 {
            return "\(minutes) min"
        }
        return "\(minutes) min \(remainder) s"
    }
}
