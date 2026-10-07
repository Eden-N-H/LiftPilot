//  LiftDetailViewModel.swift

import Foundation
import Combine

/// Drives the Lift Detail screen: the estimated max trend, the goal with its
/// planned and forecast timelines, and the next session's prescription.
@MainActor
final class LiftDetailViewModel: ObservableObject {
    struct EstimatedMaxPoint: Identifiable {
        let id: UUID
        let date: Date
        let estimatedMaxKg: Double
    }

    struct SessionHighlight: Identifiable {
        let id: UUID
        let date: Date
        let bestSet: ExerciseSet
        let estimatedMaxKg: Double
        let setCount: Int
    }

    @Published private(set) var exercise: Exercise?
    @Published private(set) var goal: LiftGoal?
    @Published private(set) var prescription: SessionPrescription?
    @Published private(set) var forecast: GoalForecast?
    @Published private(set) var trend: [EstimatedMaxPoint] = []
    @Published private(set) var recentSessions: [SessionHighlight] = []
    @Published var errorMessage: String?

    let exerciseID: UUID
    private let dependencies: AppDependencies

    init(exerciseID: UUID, dependencies: AppDependencies) {
        self.exerciseID = exerciseID
        self.dependencies = dependencies
    }

    var canHaveGoal: Bool {
        exercise?.isMainBarbellLift ?? false
    }

    func load() {
        let repository = dependencies.repository
        errorMessage = nil
        do {
            exercise = try repository.fetchExercise(id: exerciseID)
            goal = try repository.fetchActiveGoal(for: exerciseID)

            let records = LiftHistory.sessionRecords(
                from: try repository.fetchCompletedSets(for: exerciseID, since: nil)
            )
            trend = records.compactMap { record in
                record.bestEstimatedMaxKg.map {
                    EstimatedMaxPoint(id: record.sessionID, date: record.date, estimatedMaxKg: $0)
                }
            }
            recentSessions = records.reversed().prefix(8).compactMap { record in
                guard let best = record.bestSet, let estimate = record.bestEstimatedMaxKg else { return nil }
                return SessionHighlight(
                    id: record.sessionID,
                    date: record.date,
                    bestSet: best,
                    estimatedMaxKg: estimate,
                    setCount: record.sets.count
                )
            }
        } catch {
            errorMessage = "This lift's history couldn't be loaded. Please try again."
            return
        }

        prescription = nil
        forecast = nil
        guard let goal else { return }
        do {
            prescription = try dependencies.prescribeNextSession.execute(for: goal)
            forecast = try dependencies.forecastGoalAchievement.execute(for: goal)
        } catch {
            errorMessage = ErrorMessage.forLifter(error)
        }
    }
}
