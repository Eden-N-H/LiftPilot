//  OneRepMaxEstimator.swift

import Foundation

/// Estimates a lifter's one-rep max from an ordinary working set, so they never
/// have to attempt a risky true max to know where they stand.
///
/// Uses the Epley formula: weight × (1 + reps / 30).
/// - A single counts as itself (Epley would overstate it slightly).
/// - Sets above 10 reps return nil because the estimate becomes unreliable.
enum OneRepMaxEstimator {
    static func estimatedMaxKg(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, reps >= 1, reps <= ProgressionRules.maximumRepsForEstimate else {
            return nil
        }
        if reps == 1 {
            return weightKg
        }
        return weightKg * (1 + Double(reps) / 30)
    }
}
