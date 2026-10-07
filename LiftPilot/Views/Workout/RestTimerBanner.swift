//  RestTimerBanner.swift

import SwiftUI

/// The rest countdown shown at the top of the workout between sets.
struct RestTimerBanner: View {
    let endsAt: Date
    let onDismiss: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))
            HStack(spacing: 12) {
                Image(systemName: remaining > 0 ? "timer" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(remaining > 0 ? Color.orange : Color.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(remaining > 0 ? "Resting" : "Rest over")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(remaining > 0 ? Self.clock(remaining) : "Time for your next set")
                        .font(.title2.monospacedDigit().bold())
                }

                Spacer()

                Button(remaining > 0 ? "Skip" : "Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
            }
        }
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
