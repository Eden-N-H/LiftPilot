//  LiftsViewModel.swift

import Foundation
import Combine

/// Drives the Lifts screen: every exercise with its recent estimated max and
/// goal progress.
@MainActor
final class LiftsViewModel: ObservableObject {
    struct LiftRow: Identifiable {
        let exercise: Exercise
        let recentEstimatedMaxKg: Double?
        let goal: LiftGoal?

        var id: UUID { exercise.id }

        var goalProgress: Double? {
            guard let goal, goal.targetWeightKg > 0 else { return nil }
            let current = max(recentEstimatedMaxKg ?? 0, goal.startingEstimatedMaxKg)
            return min(1, current / goal.targetWeightKg)
        }
    }

    @Published private(set) var mainLifts: [LiftRow] = []
    @Published private(set) var accessories: [LiftRow] = []
    @Published var errorMessage: String?

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func load() {
        let repository = dependencies.repository
        let windowStart = Calendar.current.date(
            byAdding: .day,
            value: -ProgressionRules.forecastWindowDays,
            to: Date()
        )
        do {
            let rows = try repository.fetchExercises().map { exercise in
                let recentSets = (try? repository.fetchCompletedSets(for: exercise.id, since: windowStart)) ?? []
                return LiftRow(
                    exercise: exercise,
                    recentEstimatedMaxKg: LiftHistory.bestEstimatedMaxKg(in: recentSets),
                    goal: try? repository.fetchActiveGoal(for: exercise.id)
                )
            }
            mainLifts = rows.filter { $0.exercise.isMainBarbellLift }
            accessories = rows.filter { !$0.exercise.isMainBarbellLift }
            errorMessage = nil
        } catch {
            errorMessage = "Your lifts couldn't be loaded. Please try again."
        }
    }
}
