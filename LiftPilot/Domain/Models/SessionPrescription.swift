//  SessionPrescription.swift

import Foundation

/// Why LiftPilot chose the next session's weight and reps.
enum ProgressionDecision: Hashable {
    case startingWeight
    case addWeight(increaseKg: Double)
    case addReps
    case repeatAfterMissedSession
    case deload(fromKg: Double)

    /// A coach-style explanation written for the lifter.
    var explanation: String {
        switch self {
        case .startingWeight:
            return "A comfortable starting weight based on the set you entered. Build up the reps from here."
        case .addWeight(let increase):
            return "You hit 8 reps on every set last time, so the weight goes up \(WeightFormatting.kg(increase))."
        case .addReps:
            return "Same weight as last time. Aim for one more rep on each set."
        case .repeatAfterMissedSession:
            return "You fell short of 6 reps last time. Stay at this weight and aim for 6 on every set."
        case .deload(let fromKg):
            return "Two tough sessions in a row at \(WeightFormatting.kg(fromKg)). The weight drops about 10% so you can build back up with good reps."
        }
    }
}

/// What the lifter should do for a goal lift in their next session.
struct SessionPrescription: Hashable {
    let exerciseID: UUID
    let weightKg: Double
    let sets: Int
    let targetReps: Int
    let decision: ProgressionDecision

    var summary: String {
        "\(sets) × \(targetReps) @ \(WeightFormatting.kg(weightKg))"
    }
}
