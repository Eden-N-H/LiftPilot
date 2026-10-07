//  TrainingSnapshotPublisher.swift

import Foundation
import WidgetKit

/// Writes the latest training snapshot to the App Group container and asks
/// WidgetKit to reload. Called after every change the widget cares about:
/// logging or deleting a set, skipping rest, finishing or discarding a
/// workout, and setting a goal.
@MainActor
final class TrainingSnapshotPublisher {
    private let repository: TrainingLogRepository
    private let prescribeNextSession: PrescribeNextSessionUseCase
    private let forecastGoal: ForecastGoalAchievementUseCase

    init(
        repository: TrainingLogRepository,
        prescribeNextSession: PrescribeNextSessionUseCase,
        forecastGoal: ForecastGoalAchievementUseCase
    ) {
        self.repository = repository
        self.prescribeNextSession = prescribeNextSession
        self.forecastGoal = forecastGoal
    }

    func publish(workoutInProgress: Bool, restEndsAt: Date? = nil, upNext: UpNextSet? = nil) {
        let snapshot = TrainingSnapshot(
            generatedAt: Date(),
            workoutInProgress: workoutInProgress,
            restEndsAt: restEndsAt,
            upNext: upNext,
            featuredGoal: featuredGoalSnapshot()
        )

        do {
            try TrainingSnapshotStore.save(snapshot)
        } catch {
            print("Widget snapshot could not be written. Check the App Group ID in AppGroup.swift matches Signing & Capabilities: \(error.localizedDescription)")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The lifter's longest-standing active goal, with its next session and forecast.
    private func featuredGoalSnapshot() -> GoalSnapshot? {
        guard let goal = (try? repository.fetchActiveGoals())?.first,
              let exercise = try? repository.fetchExercise(id: goal.exerciseID),
              let prescription = try? prescribeNextSession.execute(for: goal),
              let forecast = try? forecastGoal.execute(for: goal) else {
            return nil
        }
        return GoalSnapshot(
            liftName: exercise.name,
            targetWeightKg: goal.targetWeightKg,
            estimatedMaxKg: forecast.currentEstimatedMaxKg,
            nextSessionWeightKg: prescription.weightKg,
            nextSessionSets: prescription.sets,
            nextSessionReps: prescription.targetReps,
            forecastLine: forecast.headline
        )
    }
}
