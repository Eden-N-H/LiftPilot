//  LiftDetailView.swift

import SwiftUI
import Charts

/// The goal story for one lift: estimated max trend, planned vs forecast
/// timeline, and what to do next session.
struct LiftDetailView: View {
    private let dependencies: AppDependencies
    @StateObject private var viewModel: LiftDetailViewModel
    @State private var isEditingGoal = false

    init(exerciseID: UUID, dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: LiftDetailViewModel(exerciseID: exerciseID, dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let goal = viewModel.goal {
                    goalCard(goal)
                } else if viewModel.canHaveGoal {
                    noGoalCard
                }

                if let prescription = viewModel.prescription {
                    nextSessionCard(prescription)
                }

                trendSection

                if !viewModel.recentSessions.isEmpty {
                    recentSessionsSection
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.exercise?.name ?? "Lift")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canHaveGoal {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.goal == nil ? "Set Goal" : "Change Goal") {
                        isEditingGoal = true
                    }
                }
            }
        }
        .sheet(isPresented: $isEditingGoal, onDismiss: { viewModel.load() }) {
            SetGoalView(dependencies: dependencies, exerciseID: viewModel.exerciseID)
        }
        .onAppear { viewModel.load() }
    }

    // MARK: - Goal

    private func goalCard(_ goal: LiftGoal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(WeightFormatting.kg(goal.targetWeightKg))
                        .font(.largeTitle.bold())
                }
                Spacer()
                if let forecast = viewModel.forecast {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Estimated max")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(WeightFormatting.kg(forecast.currentEstimatedMaxKg.rounded()))
                            .font(.title2.bold())
                    }
                }
            }

            if let forecast = viewModel.forecast {
                ProgressView(value: forecast.progressFraction)

                Text(forecast.headline)
                    .font(.headline)
                Text(forecast.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                timelineRow(
                    title: "Planned",
                    detail: "If every session goes to plan",
                    date: goal.plannedCompletionDate
                )
                if let forecastDate = forecast.forecastDate {
                    timelineRow(
                        title: "Forecast",
                        detail: "Based on your recent sessions",
                        date: forecastDate
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func timelineRow(title: String, detail: String, date: Date) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline.bold())
        }
    }

    private var noGoalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No goal on this lift", systemImage: "target")
                .font(.headline)
            Text("Set a target weight and LiftPilot will prescribe each session's weight and reps, and forecast when you'll get there.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Set a Goal") { isEditingGoal = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Next session

    private func nextSessionCard(_ prescription: SessionPrescription) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next session")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(prescription.summary)
                .font(.title2.bold())
            PlateLoadingText(weightKg: prescription.weightKg)
            Text(prescription.decision.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Trend

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimated max per session")
                .font(.headline)

            if viewModel.trend.count < 2 {
                Text("Log this lift in at least two workouts to see your trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(viewModel.trend) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Estimated max (kg)", point.estimatedMaxKg)
                        )
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Estimated max (kg)", point.estimatedMaxKg)
                        )
                    }
                    if let goal = viewModel.goal {
                        RuleMark(y: .value("Goal", goal.targetWeightKg))
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Goal \(WeightFormatting.kg(goal.targetWeightKg))")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 220)
            }
        }
    }

    // MARK: - Recent sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent sessions")
                .font(.headline)
            ForEach(viewModel.recentSessions) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline.bold())
                        Text("\(session.setCount) sets · best \(session.bestSet.summary)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("e1RM \(WeightFormatting.kg(session.estimatedMaxKg.rounded()))")
                        .font(.subheadline)
                }
                Divider()
            }
        }
    }
}
