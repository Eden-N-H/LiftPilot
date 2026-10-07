//  LiftGoal.swift

import Foundation

enum LiftGoalStatus: String {
    case active
    case achieved
}

/// A lifter's commitment to reach a target weight on one main barbell lift,
/// e.g. "bench press 102.5 kg".
struct LiftGoal: Identifiable, Hashable {
    let id: UUID
    let exerciseID: UUID
    var targetWeightKg: Double
    /// Estimated max from the reference set the lifter entered when setting the goal.
    var startingEstimatedMaxKg: Double
    /// How many times a week the lifter trains this lift. Drives the planned timeline.
    var sessionsPerWeek: Int
    var setAt: Date
    /// When the lifter would reach the target if every session went to plan.
    /// Fixed when the goal is set, and recalculated only after a deload.
    var plannedCompletionDate: Date
    var status: LiftGoalStatus
    var achievedAt: Date?

    var isActive: Bool {
        status == .active
    }
}
