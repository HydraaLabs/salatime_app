import XCTest
import AVFoundation
@testable import Runner

class RunnerTests: XCTestCase {
  private let base = Date(timeIntervalSince1970: 1800000000)
  private func snapshot(previous: Date? = nil, gap: TimeInterval = 3 * 3600, timeZone: String = "Africa/Casablanca") -> PrayerWidgetSnapshot {
    let previous = previous ?? base
    return PrayerWidgetSnapshot(prayers: [
      PrayerWidgetPrayer(at: previous.timeIntervalSince1970 * 1000, prayerId: 3, date: "", name: "Asr", shortName: "Asr"),
      PrayerWidgetPrayer(at: previous.addingTimeInterval(gap).timeIntervalSince1970 * 1000, prayerId: 4, date: "", name: "Maghrib", shortName: "Maghrib")
    ], city: "Fès", nextLabel: "Prochaine prière", sinceLabel: "Depuis @prayer", emptyLabel: "Ouvrez SalaTime", locale: "fr", timeZone: timeZone, use24HourFormat: true)
  }

  func testElapsedTimeStopsAtNinetyMinutes() {
    let data = snapshot()
    XCTAssertEqual(data.presentation(at: base)?.prayer.prayerId, 3)
    XCTAssertTrue(data.presentation(at: base.addingTimeInterval(5399))!.since)
    let next = data.presentation(at: base.addingTimeInterval(5400))!
    XCTAssertFalse(next.since)
    XCTAssertEqual(next.prayer.prayerId, 4)
  }

  func testRedCountdownIsStrictlyLessThanFortyFiveMinutes() {
    let data = snapshot(), next = base.addingTimeInterval(3 * 3600)
    XCTAssertFalse(data.presentation(at: next.addingTimeInterval(-2700))!.urgent)
    XCTAssertTrue(data.presentation(at: next.addingTimeInterval(-2699))!.urgent)
    XCTAssertFalse(data.presentation(at: next.addingTimeInterval(-2699), countdown: false)!.urgent)
    XCTAssertNil(data.presentation(at: next.addingTimeInterval(86400)))
  }

  func testNextPrayerOverridesRecentPrayerAtOneHourAndIsRedOnlyBelowFortyFiveMinutes() throws {
    let data = snapshot(gap: 90 * 60)
    let next = base.addingTimeInterval(90 * 60)
    for remaining in [3600.001, 3600, 2700, 2699.999, 2699] {
      let presentation = try XCTUnwrap(data.presentation(at: next.addingTimeInterval(-remaining)))
      let showsNext = remaining <= 3600
      XCTAssertEqual(presentation.prayer.prayerId, showsNext ? 4 : 3)
      XCTAssertEqual(presentation.since, !showsNext)
      XCTAssertEqual(presentation.urgent, remaining < 2700)
    }
    let dates = data.transitions(after: base, seconds: true)
    XCTAssertTrue(dates.contains(next.addingTimeInterval(-3600)))
    XCTAssertTrue(dates.contains(next.addingTimeInterval(-2700 + 1)))
    XCTAssertTrue(dates.contains(next))
  }

  func testEarlySwitchAcrossMidnightUsesNextPrayerDayAndKeepsMidnightRefresh() throws {
    let next = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-17T00:15:00Z"))
    let previous = next.addingTimeInterval(-90 * 60)
    let data = snapshot(previous: previous, gap: 90 * 60, timeZone: "UTC")
    let beforeMidnight = next.addingTimeInterval(-3600)
    let presentation = try XCTUnwrap(data.presentation(at: beforeMidnight))
    XCTAssertEqual(presentation.prayer.prayerId, 4)
    XCTAssertFalse(presentation.since)
    XCTAssertFalse(presentation.urgent)
    XCTAssertEqual(data.prayers(for: presentation.prayer).map(\.prayerId), [4])
    XCTAssertEqual(data.calendar.component(.day, from: presentation.prayer.instant), 17)
    XCTAssertEqual(data.calendar.component(.day, from: beforeMidnight), 16)
    XCTAssertTrue(data.transitions(after: previous, seconds: true)
      .contains(data.calendar.startOfDay(for: next)))
  }

  func testTimelineContainsEveryPresentationBoundary() {
    let data = snapshot(), now = base.addingTimeInterval(-1)
    let dates = data.transitions(after: now, seconds: true)
    XCTAssertEqual(dates.first, now)
    XCTAssertTrue(dates.contains(base))
    XCTAssertTrue(dates.contains(base.addingTimeInterval(5400)))
    XCTAssertTrue(dates.contains(base.addingTimeInterval(3 * 3600 - 3600)))
    XCTAssertTrue(dates.contains(base.addingTimeInterval(3 * 3600 - 2700 + 1)))
    XCTAssertEqual(dates, dates.sorted())
    XCTAssertEqual(Set(dates).count, dates.count)
  }

  func testMinuteModeHasBoundedTimelineAndOptionsClampOpacity() {
    XCTAssertLessThan(snapshot().transitions(after: base, seconds: false).count, 260)
    XCTAssertEqual(PrayerWidgetOptions(["opacity": -10]).opacity, 0)
    XCTAssertEqual(PrayerWidgetOptions(["opacity": 200]).opacity, 100)
    XCTAssertTrue(PrayerWidgetOptions().countdown)
  }

  func testMinuteCountdownRoundsUpAndElapsedRoundsDown() throws {
    let data = snapshot()
    let next = base.addingTimeInterval(3 * 3600)
    for (remaining, minutes) in [(61.0, 2), (60.0, 1), (59.0, 1), (1.0, 1)] {
      let now = next.addingTimeInterval(-remaining)
      let presentation = try XCTUnwrap(data.presentation(at: now))
      XCTAssertFalse(presentation.since)
      XCTAssertEqual(presentation.minutes(at: now), minutes)
    }
    for (elapsed, minutes) in [(0.0, 0), (59.0, 0), (60.0, 1), (61.0, 1)] {
      let now = base.addingTimeInterval(elapsed)
      let presentation = try XCTUnwrap(data.presentation(at: now))
      XCTAssertTrue(presentation.since)
      XCTAssertEqual(presentation.minutes(at: now), minutes)
    }
  }

  func testScheduleKeepsLateIshaWithItsPrayerDay() throws {
    let lateIsha = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-17T00:15:00Z"))
    let data = PrayerWidgetSnapshot(prayers: [
      PrayerWidgetPrayer(at: lateIsha.addingTimeInterval(-3 * 3600).timeIntervalSince1970 * 1000,
                         prayerId: 4, date: "2026-09-16", name: "Maghrib", shortName: "Maghrib"),
      PrayerWidgetPrayer(at: lateIsha.timeIntervalSince1970 * 1000,
                         prayerId: 5, date: "2026-09-16", name: "Isha", shortName: "Isha"),
      PrayerWidgetPrayer(at: lateIsha.addingTimeInterval(5 * 3600).timeIntervalSince1970 * 1000,
                         prayerId: 1, date: "2026-09-17", name: "Fajr", shortName: "Fajr")
    ], city: "Fès", nextLabel: "Next", sinceLabel: "Since @prayer", emptyLabel: "Open SalaTime",
       locale: "en", timeZone: "UTC", use24HourFormat: true)
    let isha = try XCTUnwrap(data.presentation(at: lateIsha.addingTimeInterval(-3600)))
    XCTAssertEqual(data.prayers(for: isha.prayer).map(\.prayerId), [4, 5])
    let fajr = try XCTUnwrap(data.presentation(at: lateIsha.addingTimeInterval(2 * 3600)))
    XCTAssertEqual(data.prayers(for: fajr.prayer).map(\.prayerId), [1])
  }
  func testAllBundledNotificationSoundsMeetIOSDurationLimit() throws {
    let files = try XCTUnwrap(Bundle.main.urls(forResourcesWithExtension: "aiff", subdirectory: nil))
    XCTAssertEqual(files.count, 68, "Every sound in the catalogue must be embedded in Runner")
    for url in files {
      let audio = try AVAudioFile(forReading: url)
      let duration = Double(audio.length) / audio.processingFormat.sampleRate
      XCTAssertGreaterThan(duration, 0, url.lastPathComponent)
      XCTAssertLessThan(duration, 30, url.lastPathComponent)
    }
  }

}
