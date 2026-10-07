//  PlateCalculator.swift

import Foundation

/// Which plates go on each side of the bar for a given total weight.
struct PlateBreakdown: Hashable {
    let barWeightKg: Double
    let platesPerSideKg: [Double]
    /// False when the weight can't be made exactly with standard plates.
    let isExact: Bool
}

/// Works out bar loading for a standard 20 kg Olympic barbell and
/// standard gym plates (25, 20, 15, 10, 5, 2.5 and 1.25 kg).
enum PlateCalculator {
    static let standardBarWeightKg = 20.0
    static let availablePlatesKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    /// The smallest total jump possible: a 1.25 kg plate on each side.
    static let smallestTotalIncrementKg = 2.5

    private static let tolerance = 0.0001

    static func breakdown(forTotalKg totalKg: Double, barWeightKg: Double = standardBarWeightKg) -> PlateBreakdown {
        var remainingPerSide = max(0, (totalKg - barWeightKg) / 2)
        var plates: [Double] = []

        for plate in availablePlatesKg {
            while remainingPerSide + tolerance >= plate {
                plates.append(plate)
                remainingPerSide -= plate
            }
        }

        let isExact = totalKg + tolerance >= barWeightKg && remainingPerSide < tolerance
        return PlateBreakdown(barWeightKg: barWeightKg, platesPerSideKg: plates, isExact: isExact)
    }

    /// Whether the weight can be loaded exactly on a standard barbell.
    static func isLoadable(_ totalKg: Double) -> Bool {
        breakdown(forTotalKg: totalKg).isExact
    }

    /// Rounds a weight down to the nearest weight that can actually be loaded,
    /// never going below the empty bar.
    static func roundDownToLoadable(_ totalKg: Double) -> Double {
        let steps = ((totalKg + tolerance) / smallestTotalIncrementKg).rounded(.down)
        return max(standardBarWeightKg, steps * smallestTotalIncrementKg)
    }

    /// The nearest loadable weights either side of a weight that can't be loaded.
    static func nearestLoadableWeights(to totalKg: Double) -> (lower: Double, upper: Double) {
        let lower = roundDownToLoadable(totalKg)
        let upper = max(standardBarWeightKg, lower + smallestTotalIncrementKg)
        return (lower, upper)
    }
}
