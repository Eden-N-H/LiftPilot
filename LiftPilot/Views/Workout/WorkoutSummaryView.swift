//  WorkoutSummaryView.swift

import SwiftUI

/// The coach's debrief after finishing a workout: how each goal lift went
/// and what changes next session.
struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDone: () -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    stat(value: "\(summary.durationMinutes)", label: "minutes")
                    stat(value: "\(summary.totalSets)", label: "sets")
                    stat(value: "\(summary.exercisesTrained)", label: "exercises")
                }
                .padding(.vertical, 6)
            }

            Section("Goal lifts") {
                if summary.goalDebriefs.isEmpty {
                    Text("No goal lifts in this workout. Your sets are saved in your history.")
                        .foregroundStyle(.secondary)
                }
                ForEach(summary.goalDebriefs) { debrief in
                    debriefRow(debrief)
                }
            }
        }
        .navigationTitle("Workout Complete")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: onDone)
                    .bold()
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func debriefRow(_ debrief: GoalLiftDebrief) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(debrief.exerciseName)
                    .font(.headline)
                Spacer()
                if debrief.goalAchieved {
                    Label("Goal reached", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }

            Text(debrief.outcomeDescription)
                .font(.subheadline)

            if let next = debrief.nextPrescription {
                Text("Next session: \(next.summary)")
                    .font(.subheadline.bold())
                Text(next.decision.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if debrief.planWasRecalculated {
                Label("Your goal timeline has been recalculated from the new weight.", systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
