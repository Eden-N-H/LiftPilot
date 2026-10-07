//  LiftPilotWidget.swift
//  Target membership: LiftPilotWidget
//
//  Two widget families, two moments in the lifter's day:
//  - Lock Screen (accessoryRectangular): during a workout, the live rest
//    countdown and the next set, without unlocking the phone.
//  - Home Screen (systemSmall): before the gym, the next session's
//    prescription for the goal lift and progress towards the target.
//
//  The widget never opens Core Data. It reads the TrainingSnapshot the main
//  app writes to the App Group container after every relevant change.

import WidgetKit
import SwiftUI

// MARK: - Timeline

nonisolated struct TrainingEntry: TimelineEntry {
    let date: Date
    let snapshot: TrainingSnapshot?
    let isResting: Bool
}

nonisolated struct TrainingTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrainingEntry {
        TrainingEntry(date: Date(), snapshot: .preview, isResting: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrainingEntry) -> Void) {
        let snapshot: TrainingSnapshot = context.isPreview
            ? TrainingSnapshot.preview
            : (TrainingSnapshotStore.load() ?? TrainingSnapshot.preview)
        completion(TrainingEntry(date: Date(), snapshot: snapshot, isResting: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainingEntry>) -> Void) {
        let now = Date()
        let snapshot = TrainingSnapshotStore.load()

        var entries: [TrainingEntry] = []
        if let restEndsAt = snapshot?.restEndsAt, restEndsAt > now {
            // Live countdown now, then switch to "rest over" when it ends.
            entries.append(TrainingEntry(date: now, snapshot: snapshot, isResting: true))
            entries.append(TrainingEntry(date: restEndsAt, snapshot: snapshot, isResting: false))
        } else {
            entries.append(TrainingEntry(date: now, snapshot: snapshot, isResting: false))
        }

        // The app reloads the widget after every change, so no polling is needed.
        completion(Timeline(entries: entries, policy: .never))
    }
}

// MARK: - Widget

struct LiftPilotWidget: Widget {
    let kind = "LiftPilotWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrainingTimelineProvider()) { entry in
            LiftPilotWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("LiftPilot")
        .description("Your rest timer and next set on the Lock Screen, and your next goal session on the Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct LiftPilotWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrainingEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenTrainingView(entry: entry)
        default:
            HomeScreenGoalView(entry: entry)
        }
    }
}

// MARK: - Lock Screen (rectangular)

struct LockScreenTrainingView: View {
    let entry: TrainingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let snapshot = entry.snapshot {
                content(for: snapshot)
            } else {
                Text("LiftPilot")
                    .font(.headline)
                Text("Open the app to set up your training")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func content(for snapshot: TrainingSnapshot) -> some View {
        if entry.isResting, let restEndsAt = snapshot.restEndsAt, restEndsAt > entry.date {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text(timerInterval: entry.date...restEndsAt, countsDown: true)
                    .monospacedDigit()
            }
            .font(.headline)
            if let next = snapshot.upNext {
                Text("Next: \(next.exerciseName)")
                    .font(.caption)
                    .lineLimit(1)
                Text("\(next.setLabel) · \(next.summary)")
                    .font(.caption)
                    .lineLimit(1)
            }
        } else if snapshot.workoutInProgress, let next = snapshot.upNext {
            Text("Rest over: lift!")
                .font(.headline)
            Text(next.exerciseName)
                .font(.caption)
                .lineLimit(1)
            Text("\(next.setLabel) · \(next.summary)")
                .font(.caption)
                .lineLimit(1)
        } else if let goal = snapshot.featuredGoal {
            Text(goal.liftName)
                .font(.headline)
                .lineLimit(1)
            Text("Next: \(goal.nextSessionSummary)")
                .font(.caption)
                .lineLimit(1)
            ProgressView(value: goal.progressFraction)
        } else {
            Text("LiftPilot")
                .font(.headline)
            Text("Set a lift goal to see your next session here")
                .font(.caption)
                .lineLimit(2)
        }
    }
}

// MARK: - Home Screen (small)

struct HomeScreenGoalView: View {
    let entry: TrainingEntry

    var body: some View {
        if let goal = entry.snapshot?.featuredGoal {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.liftName.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("Next session")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(goal.nextSessionSets) × \(goal.nextSessionReps)")
                    .font(.title3.bold())
                Text(WeightFormatting.kg(goal.nextSessionWeightKg))
                    .font(.title3.bold())
                    .foregroundStyle(.tint)

                Spacer(minLength: 2)

                ProgressView(value: goal.progressFraction)
                Text("\(WeightFormatting.kg(goal.estimatedMaxKg.rounded())) of \(WeightFormatting.kg(goal.targetWeightKg))")
                    .font(.caption2)
                    .lineLimit(1)
                Text(goal.forecastLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "target")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("No lift goal yet")
                    .font(.headline)
                Text("Open LiftPilot and set a target on a main lift.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    LiftPilotWidget()
} timeline: {
    TrainingEntry(date: .now, snapshot: .preview, isResting: false)
}

#Preview(as: .accessoryRectangular) {
    LiftPilotWidget()
} timeline: {
    TrainingEntry(
        date: .now,
        snapshot: TrainingSnapshot(
            generatedAt: .now,
            workoutInProgress: true,
            restEndsAt: Date.now.addingTimeInterval(90),
            upNext: UpNextSet(exerciseName: "Bench Press", setLabel: "Set 2 of 3", weightKg: 82.5, reps: 7),
            featuredGoal: nil
        ),
        isResting: true
    )
}
