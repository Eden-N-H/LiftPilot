//  LiftsView.swift

import SwiftUI

/// Every exercise with its recent estimated max and goal progress.
struct LiftsView: View {
    private let dependencies: AppDependencies
    @StateObject private var viewModel: LiftsViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: LiftsViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.mainLifts) { row in
                        liftLink(row)
                    }
                } header: {
                    Text("Main lifts")
                } footer: {
                    Text("Set a goal on a main lift and LiftPilot will plan each session towards it.")
                }

                Section("Accessories") {
                    ForEach(viewModel.accessories) { row in
                        liftLink(row)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Lifts")
            .onAppear { viewModel.load() }
        }
    }

    private func liftLink(_ row: LiftsViewModel.LiftRow) -> some View {
        NavigationLink {
            LiftDetailView(exerciseID: row.exercise.id, dependencies: dependencies)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(row.exercise.name)
                        .font(.body.bold())
                    Spacer()
                    if let estimate = row.recentEstimatedMaxKg {
                        Text("Est. max \(WeightFormatting.kg(estimate.rounded()))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No recent sets")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if let goal = row.goal, let progress = row.goalProgress {
                    ProgressView(value: progress) {
                        Text("Goal \(WeightFormatting.kg(goal.targetWeightKg)) · \(Int((progress * 100).rounded()))% there")
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
