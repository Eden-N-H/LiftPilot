//  AppGroup.swift
//  Target membership: LiftPilot, LiftPilotWidget, RestNotificationContent

import Foundation

/// The App Group shared container that lets the main app hand data to its extensions.
nonisolated enum LiftPilotAppGroup {
    static let identifier = "group.com.eden.LiftPilot"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

/// Formats weights the way lifters say them: "80 kg", "82.5 kg", "1.25".
nonisolated enum WeightFormatting {
    static func number(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        var text = String(format: "%.2f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    static func kg(_ value: Double) -> String {
        "\(number(value)) kg"
    }
}
