//  ExerciseCatalogue.swift

import Foundation

/// The exercises available on first launch. The four main barbell lifts can
/// have goals; accessories are logged without coaching.
enum ExerciseCatalogue {
    struct Entry {
        let name: String
        let category: ExerciseCategory
        let progressionIncrementKg: Double
    }

    static let standardExercises: [Entry] = [
        Entry(name: "Bench Press", category: .mainBarbellLift, progressionIncrementKg: 2.5),
        Entry(name: "Back Squat", category: .mainBarbellLift, progressionIncrementKg: 5),
        Entry(name: "Deadlift", category: .mainBarbellLift, progressionIncrementKg: 5),
        Entry(name: "Overhead Press", category: .mainBarbellLift, progressionIncrementKg: 2.5),
        Entry(name: "Barbell Row", category: .accessory, progressionIncrementKg: 2.5),
        Entry(name: "Romanian Deadlift", category: .accessory, progressionIncrementKg: 2.5),
        Entry(name: "Incline Dumbbell Press", category: .accessory, progressionIncrementKg: 2),
        Entry(name: "Lat Pulldown", category: .accessory, progressionIncrementKg: 2.5),
        Entry(name: "Leg Press", category: .accessory, progressionIncrementKg: 5),
        Entry(name: "Pull-up", category: .accessory, progressionIncrementKg: 2.5)
    ]
}
