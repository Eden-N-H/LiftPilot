//  AppDependencies.swift

import Foundation

/// Builds the object graph once at launch: one repository, the use cases that
/// depend on it, and the platform services that feed the extensions.
/// View models receive what they need from here.
@MainActor
final class AppDependencies {
    let repository: TrainingLogRepository

    let startWorkoutSession: StartWorkoutSessionUseCase
    let logWorkingSet: LogWorkingSetUseCase
    let finishWorkoutSession: FinishWorkoutSessionUseCase
    let setLiftGoal: SetLiftGoalUseCase
    let prescribeNextSession: PrescribeNextSessionUseCase
    let forecastGoalAchievement: ForecastGoalAchievementUseCase

    let restTimerNotifications: RestTimerNotifications
    let snapshotPublisher: TrainingSnapshotPublisher

    init(repository: TrainingLogRepository? = nil) {
        let repository = repository ?? CoreDataTrainingLogRepository()
        self.repository = repository

        startWorkoutSession = StartWorkoutSessionUseCase(repository: repository)
        logWorkingSet = LogWorkingSetUseCase(repository: repository)
        finishWorkoutSession = FinishWorkoutSessionUseCase(repository: repository)
        setLiftGoal = SetLiftGoalUseCase(repository: repository)
        prescribeNextSession = PrescribeNextSessionUseCase(repository: repository)
        forecastGoalAchievement = ForecastGoalAchievementUseCase(repository: repository)

        restTimerNotifications = RestTimerNotifications()
        snapshotPublisher = TrainingSnapshotPublisher(
            repository: repository,
            prescribeNextSession: prescribeNextSession,
            forecastGoal: forecastGoalAchievement
        )
    }
}
