// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.

import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    static let highEnergyCategory = "HIGH_ENERGY"
    static let quitAction = "QUIT_PROCESS"

    /// UNUserNotificationCenter throws NSExceptions when there is no app
    /// bundle (e.g. `swift run` on the bare binary), so gate everything.
    private var available = false

    func setUp() {
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog("ActivitySnitch: no bundle identifier — notifications disabled (dev run)")
            return
        }
        available = true
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let quit = UNNotificationAction(
            identifier: Self.quitAction, title: "Quit App", options: [.destructive])
        let category = UNNotificationCategory(
            identifier: Self.highEnergyCategory, actions: [quit], intentIdentifiers: [])
        center.setNotificationCategories([category])

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { NSLog("ActivitySnitch: notification auth error: \(error)") }
            Task { @MainActor in MonitorState.shared.notificationsDenied = !granted }
        }
    }

    func postHighEnergy(key: ProcessKey, name: String, average: Double, duration: TimeInterval) {
        guard available else {
            NSLog(
                "ActivitySnitch: would notify — %@ (pid %d) avg %.0f over %.0fs", name, key.pid,
                average, duration)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "High energy impact: \(name)"
        var body = String(
            format: "Averaged %.0f energy impact over the last %@.",
            average, Self.formatDuration(duration))
        if let raw = ProcessSampler.rawName(pid: key.pid), raw != name {
            body += " Process: \(raw) (pid \(key.pid))."
        } else {
            body += " (pid \(key.pid))"
        }
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.highEnergyCategory
        content.userInfo = [
            "pid": Int(key.pid),
            "startSec": String(key.startSec),
            "startUsec": String(key.startUsec),
            "name": name,
        ]
        let request = UNNotificationRequest(
            identifier: "energy-\(key.pid)-\(key.startSec)-\(key.startUsec)",
            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func postInfo(title: String, body: String) {
        guard available else {
            NSLog("ActivitySnitch: %@ — %@", title, body)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func formatDuration(_ d: TimeInterval) -> String {
        d >= 60
            ? String(format: "%g min", d / 60)
            : String(format: "%.0f s", d)
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) ->
            Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard response.actionIdentifier == Self.quitAction else { return }
        let info = response.notification.request.content.userInfo
        guard
            let pid = info["pid"] as? Int,
            let startSec = (info["startSec"] as? String).flatMap(UInt64.init),
            let startUsec = (info["startUsec"] as? String).flatMap(UInt64.init)
        else { return }
        let name = info["name"] as? String ?? "pid \(pid)"
        let key = ProcessKey(pid: pid_t(pid), startSec: startSec, startUsec: startUsec)
        ProcessTerminator.shared.terminate(key, name: name)
    }
}
