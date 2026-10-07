//  TodayViewModel.swift

import Foundation
import Combine

/// Drives the Today screen: what each goal lift asks of the lifter next,
/// whether a workout is in progress, and recent workouts.
@MainActor
final class TodayViewModel: ObservableObject {
    struct GoalCard: Identifiable {
        var id: UUID { goal.id }
        let goal: LiftGoal
        let exerciseName: String
        let prescription: SessionPrescription?
        let forecast: GoalForecast?
    }

    struct RecentWorkout: Identifiable {
        let id: UUID
        let date: Date
        let setCount: Int
        let exerciseNames: [String]
    }

    @Published private(set) var goalCards: [GoalCard] = []
    @Published private(set) var inProgressSession: WorkoutSession?
    @Published private(set) var recentWorkouts: [RecentWorkout] = []
    @Published var errorMessage: String?

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func load() {
        let repository = dependencies.repository
        do {
            let exercises = try repository.fetchExercises()
            let names = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })

            goalCards = try repository.fetchActiveGoals().map { goal in
                GoalCard(
                    goal: goal,
                    exerciseName: names[goal.exerciseID] ?? "Goal lift",
                    prescription: try? dependencies.prescribeNextSession.execute(for: goal),
                    forecast: try? dependencies.forecastGoalAchievement.execute(for: goal)
                )
            }

            inProgressSession = try repository.fetchInProgressSession()

            recentWorkouts = try repository.fetchRecentCompletedSessions(limit: 5).map { session in
                RecentWorkout(
                    id: session.id,
                    date: session.startedAt,
                    setCount: session.sets.count,
                    exerciseNames: session.exerciseIDsInOrder.compactMap { names[$0] }
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = "Your training log couldn't be loaded. Please try again."
        }

        // Keep the widget current, unless a workout is running (the workout
        // screen owns the rest timer in that case).
        if inProgressSession == nil {
            dependencies.snapshotPublisher.publish(workoutInProgress: false)
        }
    }

    /// Starts a new workout or resumes the current one. Returns its ID.
    func startWorkout() -> UUID? {
        do {
            let session = try dependencies.startWorkoutSession.execute()
            dependencies.restTimerNotifications.requestPermission()
            inProgressSession = session
            return session.id
        } catch {
            errorMessage = ErrorMessage.forLifter(error)
            return nil
        }
    }
}
