//  SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @AppStorage(TrainingPreferences.restDurationKey)
    private var restDurationSeconds = TrainingPreferences.defaultRestDurationSeconds
    @State private var isConfirmingSampleData = false

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Rest between sets", selection: $restDurationSeconds) {
                        ForEach(TrainingPreferences.restDurationOptions, id: \.self) { seconds in
                            Text(TrainingPreferences.restDurationLabel(seconds)).tag(seconds)
                        }
                    }
                } header: {
                    Text("Rest timer")
                } footer: {
                    Text("Starts automatically after each set. When it ends, LiftPilot notifies you with your next set and the plates to load.")
                }

                Section {
                    LabeledContent("Units", value: "Kilograms")
                    LabeledContent("Bar", value: "20 kg Olympic barbell")
                    LabeledContent("Rep scheme", value: "3 × 6–8 on goal lifts")
                } header: {
                    Text("Training rules")
                }

                Section {
                    Button("Load Sample Training History") {
                        isConfirmingSampleData = true
                    }
                    if let status = viewModel.statusMessage {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Demonstration")
                } footer: {
                    Text("Adds six weeks of bench press workouts and a 102.5 kg goal, so you can see forecasts, the trend chart and the widget without waiting for real training data.")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Add six weeks of sample bench press training?",
                isPresented: $isConfirmingSampleData,
                titleVisibility: .visible
            ) {
                Button("Add Sample Training") {
                    viewModel.loadSampleTrainingHistory()
                }
            } message: {
                Text("This replaces any active bench press goal.")
            }
        }
    }
}
