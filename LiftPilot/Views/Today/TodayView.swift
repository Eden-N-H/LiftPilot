//  TodayView.swift

import SwiftUI

/// Home screen: what each goal lift asks of the lifter next, and the button
/// to start training.
struct TodayView: View {
    private let dependencies: AppDependencies
    @StateObject private var viewModel: TodayViewModel
    @State private var activeWorkout: ActiveWorkoutRoute?
    @State private var isSettingGoal = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: TodayViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    startWorkoutCard

                    if viewModel.goalCards.isEmpty {
                        noGoalsCard
                    } else {
                        Text("Your goal lifts")
                            .font(.title3.bold())
                        ForEach(viewModel.goalCards) { card in
                            NavigationLink {
                                LiftDetailView(exerciseID: card.goal.exerciseID, dependencies: dependencies)
                            } label: {
                                GoalLiftCard(card: card)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !viewModel.recentWorkouts.isEmpty {
                        recentWorkoutsSection
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .onAppear { viewModel.load() }
            .fullScreenCover(item: $activeWorkout, onDismiss: { viewModel.load() }) { route in
                ActiveWorkoutView(sessionID: route.id, dependencies: dependencies)
            }
            .sheet(isPresented: $isSettingGoal, onDismiss: { viewModel.load() }) {
                SetGoalView(dependencies: dependencies, exerciseID: nil)
            }
        }
    }

    private var startWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.inProgressSession != nil {
                Label("Workout in progress", systemImage: "timer")
                    .font(.headline)
                Text("Pick up where you left off.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Ready to train?")
                    .font(.headline)
                Text("Your goal lifts will be waiting with today's weights.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                if let id = viewModel.startWorkout() {
                    activeWorkout = ActiveWorkoutRoute(id: id)
                }
            } label: {
                Text(viewModel.inProgressSession != nil ? "Resume Workout" : "Start Workout")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var noGoalsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No lift goals yet", systemImage: "target")
                .font(.headline)
            Text("Set a target on bench, squat, deadlift or overhead press and LiftPilot will tell you what to lift each session to get there.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Set a Lift Goal") {
                isSettingGoal = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent workouts")
                .font(.title3.bold())
            ForEach(viewModel.recentWorkouts) { workout in
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.bold())
                    Text("\(workout.setCount) sets · \(workout.exerciseNames.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                Divider()
            }
        }
    }
}

struct ActiveWorkoutRoute: Identifiable {
    let id: UUID
}

/// A goal lift's next session, progress and forecast at a glance.
struct GoalLiftCard: View {
    let card: TodayViewModel.GoalCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(card.exerciseName)
                    .font(.headline)
                Spacer()
                Text("Goal \(WeightFormatting.kg(card.goal.targetWeightKg))")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tint)
            }

            if let prescription = card.prescription {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(prescription.summary)
                        .font(.title2.bold())
                    Text(prescription.decision.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let forecast = card.forecast {
                ProgressView(value: forecast.progressFraction) {
                    HStack {
                        Text("Estimated max \(WeightFormatting.kg(forecast.currentEstimatedMaxKg.rounded()))")
                        Spacer()
                        Text(forecast.headline)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
