//  SetGoalView.swift

import SwiftUI

/// Where the lifter commits to a target weight. Shows the planned timeline
/// before they save, so the goal feels concrete.
struct SetGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SetGoalViewModel

    init(dependencies: AppDependencies, exerciseID: UUID?) {
        _viewModel = StateObject(wrappedValue: SetGoalViewModel(dependencies: dependencies, exerciseID: exerciseID))
    }

    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.isLiftLocked {
                    Section("Lift") {
                        Picker("Lift", selection: $viewModel.selectedExerciseID) {
                            ForEach(viewModel.mainLifts) { lift in
                                Text(lift.name).tag(Optional(lift.id))
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("Weight", text: $viewModel.referenceWeightText)
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    Stepper("\(viewModel.referenceReps) reps", value: $viewModel.referenceReps, in: 1...10)
                    if let estimate = viewModel.estimatedMaxKg {
                        LabeledContent("Estimated max", value: WeightFormatting.kg(estimate.rounded()))
                    }
                } header: {
                    Text("A recent set you're proud of")
                } footer: {
                    Text("Use a set of 1–10 reps with good form. LiftPilot estimates your max from it, so you never have to test a true one-rep max.")
                }

                Section {
                    HStack {
                        TextField("Target weight", text: $viewModel.targetWeightText)
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    Button("Just want to get stronger? Suggest a target") {
                        viewModel.suggestStrongerTarget()
                    }
                    .font(.subheadline)
                } header: {
                    Text("Your target")
                }

                Section {
                    Stepper(
                        "\(viewModel.sessionsPerWeek) session\(viewModel.sessionsPerWeek == 1 ? "" : "s") a week",
                        value: $viewModel.sessionsPerWeek,
                        in: SetLiftGoalUseCase.allowedSessionsPerWeek
                    )
                } header: {
                    Text("How often you train this lift")
                }

                if let planned = viewModel.plannedCompletionPreview {
                    Section {
                        LabeledContent("Planned completion", value: planned.formatted(date: .abbreviated, time: .omitted))
                    } footer: {
                        Text("This is the best case, if every session goes to plan. Once you've trained for a couple of weeks, LiftPilot also forecasts a date from your real progress.")
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(viewModel.existingGoal == nil ? "Set Lift Goal" : "Change Lift Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Goal") {
                        if viewModel.save() {
                            dismiss()
                        }
                    }
                    .bold()
                }
            }
        }
    }
}
