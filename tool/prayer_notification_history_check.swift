import Foundation

@main
enum PrayerNotificationHistoryCheck {
    static func main() {
        typealias Entry = PrayerNotificationHistory.Entry
        func entry(_ id: String, _ time: Double, kind: String? = nil,
                   thread: String = "") -> Entry {
            let payload = kind.map { "{\"id\":\(id),\"kind\":\"\($0)\"}" }
            return Entry(identifier: id, date: Date(timeIntervalSince1970: time),
                         thread: thread, payload: payload)
        }
        let before = entry("10000001", 10, kind: "before")
        let adhan = entry("10000002", 20, kind: "adhan")
        let iqama = entry("10000003", 30, kind: "after")
        let unrelated = entry("0", 40)
        let malformed = Entry(identifier: "10000004", date: Date(), thread: "", payload: "bad JSON")
        precondition(PrayerNotificationHistory.obsoleteIdentifiers(in: []).isEmpty)
        precondition(PrayerNotificationHistory.obsoleteIdentifiers(in: [iqama, unrelated]).isEmpty)
        precondition(Set(PrayerNotificationHistory.obsoleteIdentifiers(in: [iqama, before, unrelated, adhan, malformed])) == ["10000001", "10000002"])
        let grouped = entry("new-prayer", 50, thread: PrayerNotificationHistory.threadIdentifier)
        precondition(Set(PrayerNotificationHistory.obsoleteIdentifiers(in: [before, grouped, iqama])) == ["10000001", "10000003"])
        let mismatched = Entry(identifier: "10000005", date: Date(), thread: "",
                               payload: "{\"id\":10000006,\"kind\":\"adhan\"}")
        precondition(!mismatched.isPrayer)
        precondition(!entry("10000007", 60, kind: "unrelated").isPrayer)
        precondition(!entry("1", 60, kind: "adhan").isPrayer)
        let tie = entry("10000008", 30, kind: "extra_reminder")
        precondition(PrayerNotificationHistory.obsoleteIdentifiers(in: [iqama, tie]) == ["10000003"])
        precondition(PrayerNotificationHistory.obsoleteIdentifiers(in: [tie, iqama]) == ["10000003"])
        print("Prayer history: newest retained; legacy phases recognized; unrelated alerts preserved; ties deterministic.")
    }
}
