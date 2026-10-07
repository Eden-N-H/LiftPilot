//  PlateLoadingText.swift

import SwiftUI

/// "Each side: 25 + 5 + 1.25" — the plates to load for a barbell weight.
struct PlateLoadingText: View {
    let weightKg: Double

    var body: some View {
        Text(Self.description(for: weightKg))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    static func description(for weightKg: Double) -> String {
        let breakdown = PlateCalculator.breakdown(forTotalKg: weightKg)
        guard breakdown.isExact else {
            return "Can't be loaded exactly with standard plates"
        }
        if breakdown.platesPerSideKg.isEmpty {
            return "Empty bar (\(WeightFormatting.kg(breakdown.barWeightKg)))"
        }
        let plates = breakdown.platesPerSideKg.map(WeightFormatting.number).joined(separator: " + ")
        return "Each side: \(plates)"
    }
}
