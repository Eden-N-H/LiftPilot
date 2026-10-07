//  ProgressionRules.swift

import Foundation

/// The coaching constants LiftPilot's progression is built on. Kept in one place
/// so the rules the lifter is coached by are easy to read and change.
enum ProgressionRules {
    /// Every goal lift is trained as 3 working sets in the 6–8 rep range.
    static let workingSets = 3
    static let minimumReps = 6
    static let maximumReps = 8

    /// A new goal starts at 75% of the lifter's estimated max.
    static let startingIntensity = 0.75

    /// After two missed sessions in a row, the weight drops to 90%.
    static let deloadFactor = 0.90
    static let consecutiveMissesBeforeDeload = 2

    /// Estimated maxes from sets above this many reps are too unreliable to use.
    static let maximumRepsForEstimate = 10

    /// Forecasting needs enough recent sessions, spread across enough days.
    static let forecastWindowDays = 42
    static let minimumSessionsForForecast = 4
    static let minimumDaysForForecast = 14
    /// A forecast within this many days of the plan counts as "on track".
    static let onTrackToleranceDays = 7
    /// Gaining less than this per week counts as a stall.
    static let minimumWeeklyGainKg = 0.25
}
