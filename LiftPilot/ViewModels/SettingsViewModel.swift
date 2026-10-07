//  SettingsViewModel.swift

import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func loadSampleTrainingHistory() {
        do {
            let count = try SampleTrainingHistory(dependencies: dependencies).load()
            statusMessage = "Added \(count) sample workouts and a 102.5 kg bench press goal."
            errorMessage = nil
            dependencies.snapshotPublisher.publish(workoutInProgress: false)
        } catch {
            errorMessage = ErrorMessage.forLifter(error)
            statusMessage = nil
        }
    }
}
