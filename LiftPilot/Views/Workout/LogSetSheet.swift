//  LogSetSheet.swift

import SwiftUI

/// Logs a set that differs from the prescription, or a set of an accessory exercise.
struct LogSetSheet: View {
    let entry: SetEntryContext
    let errorMessage: String?
    /// Returns true when the set was saved.
    let onLog: (Double, Int) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String
    @State private var reps: Int
    @State private var inputError: String?

    init(entry: SetEntryContext, errorMessage: String?, onLog: @escaping (Double, Int) -> Bool) {
        self.entry = entry
        self.errorMessage = errorMessage
        self.onLog = onLog
        _weightText = State(initialValue: WeightFormatting.number(entry.suggestedWeightKg))
        _reps = State(initialValue: entry.suggestedReps)
    }

    private var weightKg: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    HStack {
                        TextField("Weight", text: $weightText)
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    if entry.exercise.isMainBarbellLift {
                        Stepper(
                            "Adjust by 2.5 kg",
                            onIncrement: { adjustWeight(by: PlateCalculator.smallestTotalIncrementKg) },
                            onDecrement: { adjustWeight(by: -PlateCalculator.smallestTotalIncrementKg) }
                        )
                        if let weightKg {
                            PlateLoadingText(weightKg: weightKg)
                        }
                    }
                }

                Section("Reps") {
                    Stepper("\(reps) reps", value: $reps, in: LogWorkingSetUseCase.allowedReps)
                }

                if let message = inputError ?? errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("\(entry.exercise.name) · Set \(entry.setNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log Set") { logSet() }
                        .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func adjustWeight(by amount: Double) {
        let current = weightKg ?? entry.suggestedWeightKg
        weightText = WeightFormatting.number(max(0, current + amount))
    }

    private func logSet() {
        guard let weightKg else {
            inputError = "Enter the weight in kilograms, e.g. 82.5."
            return
        }
        inputError = nil
        if onLog(weightKg, reps) {
            dismiss()
        }
    }
}
