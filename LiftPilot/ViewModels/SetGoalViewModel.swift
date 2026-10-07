//  SetGoalViewModel.swift

import Foundation
import Combine

/// Drives the Set Goal screen, where the lifter enters a recent set and a
/// target weight, and sees the planned timeline before committing.
@MainActor
final class SetGoalViewModel: ObservableObject {
    @Published var selectedExerciseID: UUID? {
        didSet { prefill() }
    }
    @Published var referenceWeightText = ""
    @Published var referenceReps = 5
    @Published var targetWeightText = ""
    @Published var sessionsPerWeek = 2
    @Published var errorMessage: String?
    @Published private(set) var existingGoal: LiftGoal?
    @Published private(set) var mainLifts: [Exercise] = []

    /// True when the screen was opened for one specific lift.
    let isLiftLocked: Bool

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies, exerciseID: UUID?) {
        self.dependencies = dependencies
        self.isLiftLocked = exerciseID != nil
        mainLifts = ((try? dependencies.repository.fetchExercises()) ?? []).filter(\.isMainBarbellLift)
        selectedExerciseID = exerciseID ?? mainLifts.first?.id
        prefill()
    }

    var selectedExercise: Exercise? {
        mainLifts.first { $0.id == selectedExerciseID }
    }

    var referenceWeightKg: Double? {
        Self.parseKg(referenceWeightText)
    }

    var targetWeightKg: Double? {
        Self.parseKg(targetWeightText)
    }

    var estimatedMaxKg: Double? {
        guard let weight = referenceWeightKg else { return nil }
        return OneRepMaxEstimator.estimatedMaxKg(weightKg: weight, reps: referenceReps)
    }

    /// A preview of the planned completion date, shown before the lifter commits.
    var plannedCompletionPreview: Date? {
        guard let exercise = selectedExercise,
              let estimatedMax = estimatedMaxKg,
              let target = targetWeightKg,
              target > estimatedMax else { return nil }
        let startingWeight = PlateCalculator.roundDownToLoadable(estimatedMax * ProgressionRules.startingIntensity)
        return GoalTimelinePlanner.plannedCompletionDate(
            startingWeightKg: startingWeight,
            incrementKg: exercise.progressionIncrementKg,
            targetWeightKg: target,
            sessionsPerWeek: sessionsPerWeek,
            from: Date()
        )
    }

    /// For lifters who "just want to get stronger": a target 10% above their
    /// estimated max, rounded up to a loadable weight.
    func suggestStrongerTarget() {
        guard let estimatedMax = estimatedMaxKg else {
            errorMessage = "Enter a recent set first so we can suggest a target."
            return
        }
        let suggestion = (estimatedMax * 1.10 / PlateCalculator.smallestTotalIncrementKg).rounded(.up)
            * PlateCalculator.smallestTotalIncrementKg
        targetWeightText = WeightFormatting.number(suggestion)
        errorMessage = nil
    }

    /// Saves the goal. Returns true when it was saved.
    func save() -> Bool {
        guard let exercise = selectedExercise else {
            errorMessage = "Choose which lift this goal is for."
            return false
        }
        guard let referenceWeight = referenceWeightKg else {
            errorMessage = "Enter the weight of a recent set in kilograms, e.g. 80."
            return false
        }
        guard let target = targetWeightKg else {
            errorMessage = "Enter your target weight in kilograms, e.g. 102.5."
            return false
        }

        do {
            try dependencies.setLiftGoal.execute(
                exerciseID: exercise.id,
                targetWeightKg: target,
                referenceWeightKg: referenceWeight,
                referenceReps: referenceReps,
                sessionsPerWeek: sessionsPerWeek,
                replacingExistingGoal: existingGoal != nil
            )
        } catch {
            errorMessage = ErrorMessage.forLifter(error)
            return false
        }

        errorMessage = nil
        let workoutRunning = (try? dependencies.repository.fetchInProgressSession()) != nil
        if !workoutRunning {
            dependencies.snapshotPublisher.publish(workoutInProgress: false)
        }
        return true
    }

    /// Fills the form from the lifter's best recent set and any existing goal.
    private func prefill() {
        guard let exerciseID = selectedExerciseID else { return }
        let repository = dependencies.repository

        existingGoal = try? repository.fetchActiveGoal(for: exerciseID)

        let windowStart = Calendar.current.date(byAdding: .day, value: -ProgressionRules.forecastWindowDays, to: Date())
        let recentSets = (try? repository.fetchCompletedSets(for: exerciseID, since: windowStart)) ?? []
        if let bestSet = recentSets.max(by: { ($0.estimatedMaxKg ?? 0) < ($1.estimatedMaxKg ?? 0) }),
           bestSet.estimatedMaxKg != nil {
            referenceWeightText = WeightFormatting.number(bestSet.weightKg)
            referenceReps = bestSet.reps
        } else {
            referenceWeightText = ""
            referenceReps = 5
        }

        if let existingGoal {
            targetWeightText = WeightFormatting.number(existingGoal.targetWeightKg)
            sessionsPerWeek = existingGoal.sessionsPerWeek
        } else {
            targetWeightText = ""
            sessionsPerWeek = 2
        }
    }

    private static func parseKg(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "kg", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }
}
