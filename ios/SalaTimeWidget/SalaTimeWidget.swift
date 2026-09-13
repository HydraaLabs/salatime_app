import SwiftUI
import WidgetKit

struct SalaTimeEntry: TimelineEntry {
    let date: Date
    let snapshot: PrayerWidgetSnapshot?
    let options: PrayerWidgetOptions
}

struct SalaTimeProvider: TimelineProvider {
    func placeholder(in context: Context) -> SalaTimeEntry {
        let now = Date()
        let snapshot = PrayerWidgetSnapshot(
            prayers: [PrayerWidgetPrayer(at: now.addingTimeInterval(3600).timeIntervalSince1970 * 1000,
                                         prayerId: 3, date: "", name: "Asr", shortName: "Asr")],
            city: "SalaTime", nextLabel: "Next prayer", sinceLabel: "Time since @prayer",
            emptyLabel: "Open SalaTime", locale: "en", timeZone: TimeZone.current.identifier,
            use24HourFormat: true
        )
        return SalaTimeEntry(date: now, snapshot: snapshot, options: PrayerWidgetOptions())
    }
    func getSnapshot(in context: Context, completion: @escaping (SalaTimeEntry) -> Void) {
        if context.isPreview && PrayerWidgetStore.read() == nil { completion(placeholder(in: context)); return }
        completion(SalaTimeEntry(date: Date(), snapshot: PrayerWidgetStore.read(), options: PrayerWidgetStore.options))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SalaTimeEntry>) -> Void) {
        let now = Date(), snapshot = PrayerWidgetStore.read(), options = PrayerWidgetStore.options
        let dates = snapshot?.transitions(after: now, seconds: options.seconds) ?? [now]
        let entries = dates.map { SalaTimeEntry(date: $0, snapshot: snapshot, options: options) }
        completion(Timeline(entries: entries, policy: .after(dates.last!.addingTimeInterval(60))))
    }
}

struct SalaTimeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: SalaTimeEntry
    private var primary: Color { colorScheme == .dark ? Color(red: 0.56, green: 0.71, blue: 0.57) : Color(red: 0.184, green: 0.322, blue: 0.2) }
    private var backdrop: Color { colorScheme == .dark ? Color(red: 0.08, green: 0.13, blue: 0.09) : Color(red: 0.961, green: 0.965, blue: 0.937) }
    private var small: Bool { family == .systemSmall }
    private var snapshot: PrayerWidgetSnapshot? { entry.snapshot }
    private var presentation: PrayerWidgetPresentation? { snapshot?.presentation(at: entry.date, countdown: entry.options.countdown) }

    var body: some View {
        content
            .foregroundColor(primary)
            .environment(\.locale, Locale(identifier: snapshot?.locale ?? "en"))
            .environment(\.layoutDirection, ["ar", "fa", "ur"].contains(String((snapshot?.locale ?? "en").prefix(2))) ? .rightToLeft : .leftToRight)
            .widgetURL(URL(string: "salatime://home"))
            .modifier(WidgetBackground(color: backdrop.opacity(Double(entry.options.opacity) / 100)))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: small ? 6 : 10) {
            HStack(spacing: 6) {
                if entry.options.illustration { Image(systemName: "moon.stars.fill").foregroundColor(Color(red: 0.67, green: 0.51, blue: 0.22)) }
                Text("SalaTime").font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                if entry.options.city && !small, let city = snapshot?.city { Text(city).font(.caption).lineLimit(1) }
            }
            if let current = presentation, let data = snapshot {
                Text(current.since ? data.sinceLabel.replacingOccurrences(of: "@prayer", with: current.prayer.name) : data.nextLabel)
                    .font(.caption).lineLimit(2)
                if small {
                    Text(current.prayer.name).font(.headline).lineLimit(1).minimumScaleFactor(0.75)
                    counter(current, data: data).font(.system(size: 28, weight: .semibold, design: .rounded))
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(current.prayer.name).font(.title2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                        Spacer(minLength: 8)
                        counter(current, data: data).font(.system(size: 32, weight: .semibold, design: .rounded))
                    }
                }
                if family == .systemLarge {
                    Divider()
                    ForEach(data.prayers(on: entry.date), id: \.at) { prayer in
                        HStack {
                            Text(prayer.name).lineLimit(1)
                            Spacer()
                            Text(clock(prayer.instant, data: data)).monospacedDigit()
                        }
                        .font(.subheadline)
                        .foregroundColor(prayer.instant < entry.date ? .secondary : primary)
                    }
                }
                Spacer(minLength: 0)
                if entry.options.date { Text(day(entry.date, data: data)).font(.caption2).lineLimit(1) }
            } else {
                Spacer()
                Text(snapshot?.emptyLabel ?? NSLocalizedString("widget_open", comment: "Open app to load prayer times"))
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
    }

    @ViewBuilder private func counter(_ current: PrayerWidgetPresentation, data: PrayerWidgetSnapshot) -> some View {
        Group {
            if !entry.options.countdown {
                Text(clock(current.prayer.instant, data: data))
            } else if entry.options.seconds {
                Text(current.prayer.instant, style: .timer)
            } else {
                let minutes = Int(abs(current.prayer.instant.timeIntervalSince(entry.date)) / 60)
                Text(String(format: "%02d:%02d", minutes / 60, minutes % 60))
            }
        }
        .monospacedDigit()
        .foregroundColor(current.urgent ? (colorScheme == .dark ? Color(red: 1, green: 0.56, blue: 0.56) : Color(red: 0.72, green: 0.12, blue: 0.12)) : primary)
        .lineLimit(1)
        .accessibilityLabel(Text(current.since ? data.sinceLabel.replacingOccurrences(of: "@prayer", with: current.prayer.name) : data.nextLabel))
    }
    private func clock(_ date: Date, data: PrayerWidgetSnapshot) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: data.locale); formatter.timeZone = data.zone
        formatter.dateFormat = data.use24HourFormat ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
    private func day(_ date: Date, data: PrayerWidgetSnapshot) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: data.locale); formatter.timeZone = data.zone
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter.string(from: date)
    }
}

private struct WidgetBackground: ViewModifier {
    let color: Color
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 17.0, *) { content.containerBackground(color, for: .widget) }
        else { content.padding(14).background(color) }
    }
}

@main
struct SalaTimeWidget: Widget {
    let kind = PrayerWidgetStore.kind
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SalaTimeProvider()) { entry in SalaTimeWidgetView(entry: entry) }
            .configurationDisplayName("SalaTime")
            .description(NSLocalizedString("widget_description", comment: "Prayer widget description"))
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
