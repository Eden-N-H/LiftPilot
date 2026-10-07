//  RestTimerNotifications.swift

import Foundation
import UserNotifications

/// Schedules the "rest over" notification that the RestNotificationContent
/// extension renders with the next set and the plates to load.
@MainActor
final class RestTimerNotifications {
    static let requestIdentifier = "liftpilot.rest-timer"

    private let center = UNUserNotificationCenter.current()

    func registerCategories() {
        let restComplete = UNNotificationCategory(
            identifier: RestCompletePayload.categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([restComplete])
    }

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("Notification permission request failed: \(error.localizedDescription)")
            } else if !granted {
                print("Notifications are off, so rest timer alerts won't appear.")
            }
        }
    }

    func scheduleRestComplete(at date: Date, payload: RestCompletePayload) {
        let content = UNMutableNotificationContent()
        content.title = "Rest over: \(payload.exerciseName)"
        content.body = "\(payload.setLabel): \(WeightFormatting.kg(payload.weightKg)) × \(payload.reps). Press and hold to see the plates."
        content.sound = .default
        content.categoryIdentifier = RestCompletePayload.categoryIdentifier
        content.userInfo = payload.userInfo

        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.requestIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        center.add(request) { error in
            if let error {
                print("Rest timer notification could not be scheduled: \(error.localizedDescription)")
            }
        }
    }

    func cancelRestComplete() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.requestIdentifier])
    }
}

/// Lets the rest notification appear as a banner even while LiftPilot is open,
/// since lifters often leave the app on screen between sets.
final class RestNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
