//  ExerciseSet.swift

import Foundation

/// One set the lifter performed: a weight lifted for a number of reps.
struct ExerciseSet: Identifiable, Hashable {
    let id: UUID
    let sessionID: UUID
    let exerciseID: UUID
    var weightKg: Double
    var reps: Int
    var loggedAt: Date

    /// The lifter's estimated one-rep max implied by this set, or nil when the
    /// set had too many reps for the estimate to be trustworthy.
    var estimatedMaxKg: Double? {
        OneRepMaxEstimator.estimatedMaxKg(weightKg: weightKg, reps: reps)
    }

    var summary: String {
        "\(WeightFormatting.kg(weightKg)) × \(reps)"
    }
}
