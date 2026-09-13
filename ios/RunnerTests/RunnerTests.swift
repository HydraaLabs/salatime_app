import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  private let base = Date(timeIntervalSince1970: 1800000000)
  private func snapshot() -> PrayerWidgetSnapshot {
    PrayerWidgetSnapshot(prayers: [
      PrayerWidgetPrayer(at: base.timeIntervalSince1970 * 1000, prayerId: 3, date: "", name: "Asr", shortName: "Asr"),
      PrayerWidgetPrayer(at: base.addingTimeInterval(3 * 3600).timeIntervalSince1970 * 1000, prayerId: 4, date: "", name: "Maghrib", shortName: "Maghrib")
    ], city: "Fès", nextLabel: "Prochaine prière", sinceLabel: "Depuis @prayer", emptyLabel: "Ouvrez SalaTime", locale: "fr", timeZone: "Africa/Casablanca", use24HourFormat: true)
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

  func testTimelineContainsEveryPresentationBoundary() {
    let data = snapshot(), now = base.addingTimeInterval(-1)
    let dates = data.transitions(after: now, seconds: true)
    XCTAssertEqual(dates.first, now)
    XCTAssertTrue(dates.contains(base))
    XCTAssertTrue(dates.contains(base.addingTimeInterval(5400)))
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
}
