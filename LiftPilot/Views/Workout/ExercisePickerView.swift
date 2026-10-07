//  ExercisePickerView.swift

import SwiftUI

/// Chooses an exercise to add to the current workout.
struct ExercisePickerView: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    let inCategory = exercises.filter { $0.category == category }
                    if !inCategory.isEmpty {
                        Section(category.displayName) {
                            ForEach(inCategory) { exercise in
                                Button(exercise.name) {
                                    onSelect(exercise)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                if exercises.isEmpty {
                    Text("Every exercise is already in this workout.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
