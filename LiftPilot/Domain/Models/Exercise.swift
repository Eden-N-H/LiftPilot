//  Exercise.swift

import Foundation

/// Whether an exercise is one of the main barbell lifts that LiftPilot can coach
/// towards a goal, or an accessory exercise that is simply logged.
enum ExerciseCategory: String, CaseIterable {
    case mainBarbellLift
    case accessory

    var displayName: String {
        switch self {
        case .mainBarbellLift: return "Main lifts"
        case .accessory: return "Accessories"
        }
    }
}

/// A movement the lifter performs, e.g. Bench Press or Lat Pulldown.
struct Exercise: Identifiable, Hashable {
    let id: UUID
    var name: String
    var category: ExerciseCategory
    /// How much weight is added when the lifter earns a progression:
    /// 2.5 kg for upper-body lifts, 5 kg for squat and deadlift.
    var progressionIncrementKg: Double

    var isMainBarbellLift: Bool {
        category == .mainBarbellLift
    }
}
