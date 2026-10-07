//  ActiveWorkoutView.swift

import SwiftUI

/// The in-gym logging screen. Goal lifts show today's prescribed sets so the
/// lifter can log each one with a single tap.
struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ActiveWorkoutViewModel

    @State private var isAddingExercise = false
    @State private var setEntry: SetEntryContext?
    @State private var isConfirmingFinish = false
    @State private var isConfirmingDiscard = false

    init(sessionID: UUID, dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: ActiveWorkoutViewModel(sessionID: sessionID, dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let summary = viewModel.summary {
                    WorkoutSummaryView(summary: summary) { dismiss() }
                } else {
                    workoutList
                }
            }
        }
        .onChange(of: viewModel.workoutWasDiscarded) {
            if viewModel.workoutWasDiscarded {
                dismiss()
            }
        }
    }

    private var workoutList: some View {
        List {
            if let restEndsAt = viewModel.restEndsAt {
                Section {
                    RestTimerBanner(endsAt: restEndsAt) { viewModel.skipRest() }
                }
            }

            if viewModel.blocks.isEmpty {
                Section {
                    Text("Add your first exercise to start logging sets.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(viewModel.blocks) { block in
                exerciseSection(block)
            }

            Section {
                Button {
                    isAddingExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            }

            if let errorMessage = viewModel.errorMessage, setEntry == nil {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Hide Workout (keep it running)") { dismiss() }
                    Button("Discard Workout", role: .destructive) { isConfirmingDiscard = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { isConfirmingFinish = true }
                    .bold()
            }
        }
        .confirmationDialog("Finish this workout?", isPresented: $isConfirmingFinish, titleVisibility: .visible) {
            Button("Finish Workout") { viewModel.finishWorkout() }
        } message: {
            Text("\(viewModel.totalSetsLogged) sets logged. LiftPilot will plan your next session from these.")
        }
        .confirmationDialog("Discard this workout?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
            Button("Discard Workout", role: .destructive) { viewModel.discardWorkout() }
        } message: {
            Text("Every set logged in this workout will be deleted.")
        }
        .sheet(item: $setEntry) { entry in
            LogSetSheet(entry: entry, errorMessage: viewModel.errorMessage) { weight, reps in
                viewModel.logSet(exerciseID: entry.exercise.id, weightKg: weight, reps: reps)
            }
        }
        .sheet(isPresented: $isAddingExercise) {
            ExercisePickerView(exercises: viewModel.exercisesNotYetAdded) { exercise in
                viewModel.addExercise(exercise)
            }
        }
    }

    @ViewBuilder
    private func exerciseSection(_ block: ActiveWorkoutViewModel.ExerciseBlock) -> some View {
        Section {
            if let prescription = block.prescription {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today: \(prescription.summary)")
                        .font(.subheadline.bold())
                    Text(prescription.decision.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let lastSession = block.lastSessionSummary {
                Text("Last session: \(lastSession)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(block.loggedSets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    Text("Set \(index + 1)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(set.summary)
                        .bold()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        viewModel.deleteSet(set)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if let planned = block.nextPlannedSet {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set \(planned.number) of \(block.prescription?.sets ?? planned.number)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(WeightFormatting.kg(planned.weightKg)) × \(planned.reps)")
                            .font(.title3.bold())
                        if block.exercise.isMainBarbellLift {
                            PlateLoadingText(weightKg: planned.weightKg)
                        }
                    }
                    Spacer()
                    Button("Done") {
                        viewModel.logPlannedSet(for: block)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Button {
                viewModel.errorMessage = nil
                setEntry = SetEntryContext(block: block)
            } label: {
                Label(block.nextPlannedSet == nil ? "Log a Set" : "Log Different Reps or Weight",
                      systemImage: "square.and.pencil")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
        } header: {
            HStack(spacing: 6) {
                Text(block.exercise.name)
                if block.goal != nil {
                    Text("GOAL LIFT")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }
        }
    }
}

/// What the Log Set sheet needs to prefill itself.
struct SetEntryContext: Identifiable {
    let id = UUID()
    let exercise: Exercise
    let setNumber: Int
    let suggestedWeightKg: Double
    let suggestedReps: Int

    init(block: ActiveWorkoutViewModel.ExerciseBlock) {
        exercise = block.exercise
        setNumber = block.loggedSets.count + 1
        suggestedWeightKg = block.suggestedWeightKg
        suggestedReps = block.suggestedReps
    }
}
