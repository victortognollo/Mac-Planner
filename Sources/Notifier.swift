import AppKit
import UserNotifications

/// Local notifications: reminders at their time, meetings 5 minutes before, and the end of a focus session.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    private let center = UNUserNotificationCenter.current()
    private let itemPrefix = "item-"
    private let timerID = "focus-timer"

    func setup() {
        center.delegate = self
        updateCategories()
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error { NSLog("Planner: notifications not authorized: \(error.localizedDescription)") }
        }
    }

    /// The "Join" button on meeting alerts, in the current language.
    func updateCategories() {
        let join = UNNotificationAction(identifier: "JOIN", title: tr("Join"), options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "MEETING", actions: [join], intentIdentifiers: [], options: [])
        ])
    }

    func reschedule(_ items: [PlannerItem]) {
        let now = Date()
        var planned: [(Date, UNNotificationRequest)] = []

        for item in items where !item.done && item.kind != .task {
            guard let time = item.time, let start = Day.fireDate(day: item.date, time: time) else { continue }
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.body = "\(time) · \(item.title)"
            let fire: Date
            if item.kind == .meeting {
                fire = start.addingTimeInterval(-5 * 60)
                content.title = tr("Meeting in 5 minutes")
                if let url = item.linkURL {
                    content.userInfo = ["link": url.absoluteString]
                    content.categoryIdentifier = "MEETING"
                }
            } else {
                fire = start
                content.title = tr("Reminder")
            }
            guard fire > now else { continue }
            let comps = Day.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            planned.append((fire, UNNotificationRequest(identifier: itemPrefix + item.id.uuidString, content: content, trigger: trigger)))
        }

        // macOS keeps at most 64 pending notifications per app.
        let next = planned.sorted { $0.0 < $1.0 }.prefix(60).map(\.1)
        let keep = Set(next.map(\.identifier))

        center.getPendingNotificationRequests { [center, itemPrefix] pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(itemPrefix) && !keep.contains($0) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            next.forEach { center.add($0) }
        }
    }

    func scheduleTimerEnd(after seconds: Int, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = tr("Focus session done")
        content.body = Lang.isPortuguese ? "\(minutes) min somados ao seu dia" : "\(minutes) min added to your day"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        center.add(UNNotificationRequest(identifier: timerID, content: content, trigger: trigger))
    }

    func cancelTimerEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [timerID])
    }

    // Show banners even while the planner is the active app.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    // "Entrar" (or a click on a meeting alert) opens the meeting link.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        if action == "JOIN" || action == UNNotificationDefaultActionIdentifier,
           let raw = response.notification.request.content.userInfo["link"] as? String,
           let url = URL(string: raw) {
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
        }
        completionHandler()
    }
}
