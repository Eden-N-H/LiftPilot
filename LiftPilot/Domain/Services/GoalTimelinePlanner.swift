//  GoalTimelinePlanner.swift

import Foundation

/// Works out the planned timeline for a goal: how long it would take if every
/// session went to plan under double progression (one more rep each session,
/// then more weight once every set reaches 8 reps).
///
/// This is deliberately the best case. The forecast, based on the lifter's real
/// results, is shown alongside it so the gap is visible.
enum GoalTimelinePlanner {
    /// Safety cap so an unrealistic goal can't loop forever.
    static let maximumPlannedSessions = 520

    static func plannedSessionCount(
        startingWeightKg: Double,
        startingTargetReps: Int,
        incrementKg: Double,
        targetWeightKg: Double
    ) -> Int {
        var weight = startingWeightKg
        var reps = startingTargetReps
        var sessions = 0

        while sessions < maximumPlannedSessions {
            sessions += 1
            if let estimate = OneRepMaxEstimator.estimatedMaxKg(weightKg: weight, reps: reps),
               estimate >= targetWeightKg {
                return sessions
            }
            if reps >= ProgressionRules.maximumReps {
                weight += incrementKg
                reps = ProgressionRules.minimumReps
            } else {
                reps += 1
            }
        }
        return sessions
    }

    static func plannedCompletionDate(
        startingWeightKg: Double,
        startingTargetReps: Int = ProgressionRules.minimumReps,
        incrementKg: Double,
        targetWeightKg: Double,
        sessionsPerWeek: Int,
        from startDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        let sessions = plannedSessionCount(
            startingWeightKg: startingWeightKg,
            startingTargetReps: startingTargetReps,
            incrementKg: incrementKg,
            targetWeightKg: targetWeightKg
        )
        let weeks = Double(sessions) / Double(max(1, sessionsPerWeek))
        let days = Int((weeks * 7).rounded(.up))
        return calendar.date(byAdding: .day, value: days, to: startDate) ?? startDate
    }
}
