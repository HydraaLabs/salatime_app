import Foundation

struct PrayerWidgetPrayer: Codable {
    let at: Double
    let prayerId: Int
    let date: String
    let name: String
    let shortName: String?
    var instant: Date { Date(timeIntervalSince1970: at / 1000) }
    var id: String { "\(date):\(prayerId)" }
}

struct PrayerWidgetSnapshot: Codable {
    let prayers: [PrayerWidgetPrayer]
    let city: String
    let nextLabel: String
    let sinceLabel: String
    let emptyLabel: String
    let locale: String
    let timeZone: String
    let use24HourFormat: Bool

    var zone: TimeZone { TimeZone(identifier: timeZone) ?? .current }
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    func presentation(at date: Date, countdown: Bool = true) -> PrayerWidgetPresentation? {
        guard let next = prayers.first(where: { $0.instant > date }) else { return nil }
        if countdown, let previous = prayers.last(where: { $0.instant <= date }),
           date.timeIntervalSince(previous.instant) < 90 * 60,
           next.instant.timeIntervalSince(date) > 60 * 60 {
            return PrayerWidgetPresentation(prayer: previous, since: true, urgent: false)
        }
        return PrayerWidgetPresentation(
            prayer: next, since: false,
            urgent: countdown && next.instant.timeIntervalSince(date) < 45 * 60
        )
    }

    func prayers(on date: Date) -> [PrayerWidgetPrayer] {
        prayers.filter { calendar.isDate($0.instant, inSameDayAs: date) }
    }

    // WidgetKit renders the system timer between these transitions. No polling,
    // GPS request or network access is needed in the extension.
    func transitions(after now: Date, seconds: Bool) -> [Date] {
        let horizon = now.addingTimeInterval(seconds ? 48 * 3600 : 4 * 3600)
        var dates = Set<Date>([now, horizon])
        for prayer in prayers {
            for date in [prayer.instant, prayer.instant.addingTimeInterval(90 * 60),
                         prayer.instant.addingTimeInterval(-60 * 60),
                         prayer.instant.addingTimeInterval(-45 * 60 + 1)] {
                if date > now && date < horizon { dates.insert(date) }
            }
        }
        var midnight = calendar.startOfDay(for: now)
        while let next = calendar.date(byAdding: .day, value: 1, to: midnight), next < horizon {
            dates.insert(next)
            midnight = next
        }
        if !seconds {
            var minute = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 / 60) * 60 + 60)
            while minute < horizon {
                dates.insert(minute)
                minute.addTimeInterval(60)
            }
        }
        return dates.sorted()
    }
}

struct PrayerWidgetPresentation {
    let prayer: PrayerWidgetPrayer
    let since: Bool
    let urgent: Bool
}

struct PrayerWidgetOptions {
    var countdown = true
    var seconds = true
    var city = true
    var date = true
    var illustration = true
    var opacity = 100

    init(_ values: [String: Any] = [:]) {
        countdown = values["countdown"] as? Bool ?? true
        seconds = values["seconds"] as? Bool ?? true
        city = values["city"] as? Bool ?? true
        date = values["date"] as? Bool ?? true
        illustration = values["illustration"] as? Bool ?? true
        opacity = min(100, max(0, values["opacity"] as? Int ?? 100))
    }
    var dictionary: [String: Any] {
        ["countdown": countdown, "seconds": seconds, "city": city,
         "date": date, "illustration": illustration, "opacity": opacity]
    }
}

// Only display data and widget options are shared, never account credentials.
enum PrayerWidgetStore {
    static let kind = "SalaTimePrayerWidget"
    static var group: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SalaTimeAppGroup") as? String,
              value.hasPrefix("group."), !value.contains("$(") else { return nil }
        return value
    }
    static var container: URL? {
        guard let group = group else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }
    static var options: PrayerWidgetOptions {
        guard let group = group else { return PrayerWidgetOptions() }
        return PrayerWidgetOptions(UserDefaults(suiteName: group)?.dictionary(forKey: "widgetOptions") ?? [:])
    }
    static func saveOptions(_ values: [String: Any]) -> Bool {
        guard container != nil, let group = group, let defaults = UserDefaults(suiteName: group) else { return false }
        var options = self.options.dictionary
        for key in ["countdown", "seconds", "city", "date", "illustration"] {
            if let value = values[key] as? Bool { options[key] = value }
        }
        if let value = values["opacity"] as? Int { options["opacity"] = min(100, max(0, value)) }
        defaults.set(options, forKey: "widgetOptions")
        return true
    }
    static func read() -> PrayerWidgetSnapshot? {
        guard let url = container?.appendingPathComponent("prayer-widget.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PrayerWidgetSnapshot.self, from: data)
    }
    static func save(_ payload: [String: Any]) throws {
        guard let container = container else {
            throw NSError(domain: "SalaTimeWidget", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group is not configured"])
        }
        guard let encoded = payload["prayers"] as? String, let data = encoded.data(using: .utf8) else {
            throw NSError(domain: "SalaTimeWidget", code: 2)
        }
        let prayers = try JSONDecoder().decode([PrayerWidgetPrayer].self, from: data)
        guard !prayers.isEmpty, prayers.count <= 400,
              prayers.allSatisfy({ $0.at.isFinite && $0.at > 0 && (1...5).contains($0.prayerId) }) else {
            throw NSError(domain: "SalaTimeWidget", code: 3)
        }
        let snapshot = PrayerWidgetSnapshot(
            prayers: prayers.sorted { $0.at < $1.at }, city: payload["city"] as? String ?? "",
            nextLabel: payload["nextLabel"] as? String ?? "Next prayer",
            sinceLabel: payload["sinceLabel"] as? String ?? "Time since @prayer",
            emptyLabel: payload["emptyLabel"] as? String ?? "Open SalaTime to refresh",
            locale: payload["locale"] as? String ?? "en", timeZone: payload["timeZone"] as? String ?? "UTC",
            use24HourFormat: payload["use24HourFormat"] as? Bool ?? true
        )
        try JSONEncoder().encode(snapshot).write(to: container.appendingPathComponent("prayer-widget.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
