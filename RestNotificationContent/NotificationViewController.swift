//  NotificationViewController.swift
//  Target membership: RestNotificationContent
//
//  Replaces the default appearance of the REST_COMPLETE notification. When
//  the lifter presses and holds the "rest over" notification, they see the
//  next set, the plates to load on each side of the bar, how the same set
//  went last session, and progress towards their goal.

import UIKit
import SwiftUI
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    // Kept so the template's storyboard connection still resolves; hidden
    // unless the payload can't be read.
    @IBOutlet var label: UILabel?

    private var hostingController: UIHostingController<RestCompleteNotificationView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        label?.isHidden = true
    }

    func didReceive(_ notification: UNNotification) {
        guard let payload = RestCompletePayload(userInfo: notification.request.content.userInfo) else {
            label?.isHidden = false
            label?.text = notification.request.content.body
            return
        }

        let content = RestCompleteNotificationView(payload: payload)

        if let hostingController {
            hostingController.rootView = content
            return
        }

        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host

        preferredContentSize = CGSize(width: view.bounds.width, height: 250)
    }
}
