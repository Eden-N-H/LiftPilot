//  LiftPilotApp.swift

import SwiftUI
import UserNotifications

@main
struct LiftPilotApp: App {
    private let dependencies = AppDependencies()
    private let notificationPresenter = RestNotificationPresenter()

    init() {
        UNUserNotificationCenter.current().delegate = notificationPresenter
        dependencies.restTimerNotifications.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}
