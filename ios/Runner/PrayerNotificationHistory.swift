import Foundation
import UserNotifications

enum PrayerNotificationHistory {
    static let threadIdentifier = "salatime.prayer-reminders"

    struct Entry {
        let identifier: String
        let date: Date
        let thread: String
        let payload: String?

        var isPrayer: Bool {
            if thread == PrayerNotificationHistory.threadIdentifier { return true }
            // Recognize alerts delivered by older builds before grouping existed.
            guard let id = Int(identifier),
                  (10_000_000..<30_000_000).contains(id) || id == 1_999_000_001,
                  let bytes = payload?.data(using: .utf8),
                  let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
                  value["id"] as? Int == id,
                  let kind = value["kind"] as? String else { return false }
            return ["adhan", "before", "after", "extra_reminder"].contains(kind)
        }
    }

    static func obsoleteIdentifiers(in entries: [Entry]) -> [String] {
        let prayers = entries.filter { $0.isPrayer }.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            return $0.identifier > $1.identifier
        }
        return prayers.dropFirst().map { $0.identifier }
    }

    static func retainLatestDelivered() {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { notifications in
            let entries = notifications.map {
                Entry(identifier: $0.request.identifier, date: $0.date,
                      thread: $0.request.content.threadIdentifier,
                      payload: $0.request.content.userInfo["payload"] as? String)
            }
            let obsolete = obsoleteIdentifiers(in: entries)
            if !obsolete.isEmpty {
                // Delivered history only: never cancel any pending prayer alarm.
                center.removeDeliveredNotifications(withIdentifiers: obsolete)
            }
        }
    }
}
