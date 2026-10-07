//  WorkoutSummary.swift

import Foundation

/// How a goal lift went in the workout that was just finished, and what happens next.
struct GoalLiftDebrief: Identifiable, Hashable {
    var id: UUID { goalID }
    let goalID: UUID
    let exerciseName: String
    let outcome: WorkingSetOutcome
    let nextPrescription: SessionPrescription?
    let goalAchieved: Bool
    let planWasRecalculated: Bool

    var outcomeDescription: String {
        if goalAchieved {
            return "You lifted your target weight. Goal reached!"
        }
        switch outcome {
        case .reachedTopOfRange:
            return "Every working set hit 8 reps."
        case .withinRange(let lowestReps):
            return "All working sets in the 6–8 range (lowest set: \(lowestReps) reps)."
        case .missed:
            return "Some working sets fell short of 6 reps."
        }
    }
}

/// The coach's debrief shown when a workout is finished.
struct WorkoutSummary: Hashable {
    let sessionID: UUID
    let startedAt: Date
    let finishedAt: Date
    let totalSets: Int
    let exercisesTrained: Int
    let goalDebriefs: [GoalLiftDebrief]

    var durationMinutes: Int {
        max(1, Int(finishedAt.timeIntervalSince(startedAt) / 60))
    }
}
