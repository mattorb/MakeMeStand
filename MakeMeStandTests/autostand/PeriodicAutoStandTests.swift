import Combine
import Foundation
import Testing
import TestingExpectation

@testable import MakeMeStand

class PeriodicAutoStandTests {
  @Test
  func testNextSpanNoOverlap() async throws {
    let settings = Settings(userDefaultsProvider: FakeUserDefaultsProvider())

    let scenarios: [(currentTime: Date, expectedStandTime: Date, expectedSitTime: Date)] = [
      (.todayAt(hour: 10, minute: 30), .todayAt(hour: 10, minute: 55), .todayAt(hour: 11, minute: 00)),
      (.todayAt(hour: 10, minute: 58), .todayAt(hour: 11, minute: 55), .todayAt(hour: 12, minute: 00)),
      (.todayAt(hour: 11, minute: 00), .todayAt(hour: 11, minute: 55), .todayAt(hour: 12, minute: 00)),
      (.todayAt(hour: 11, minute: 01), .todayAt(hour: 11, minute: 55), .todayAt(hour: 12, minute: 00)),
    ]

    for scenario in scenarios {
      let autoStand = PeriodicAutoStand(
        settings: settings,
        stand: {},
        sit: {},
        currentTimeProvider: MockTimeProvider(simulatedDate: scenario.currentTime)
      )

      #expect(autoStand.nextSpan?.stand == scenario.expectedStandTime)
      #expect(autoStand.nextSpan?.sit == scenario.expectedSitTime)
    }
  }

  @Test
  func shouldTriggerStand() async {
    let standExpectation = Expectation()
    let autoStand = PeriodicAutoStand(
      settings: Settings(),
      stand: { standExpectation.fulfill() },
      sit: { Issue.record("Should not fire sit") },
      currentTimeProvider: MockTimeProvider(simulatedDate: .todayAt(hour: 10, minute: 10))
    )

    autoStand.adjustHeightIfNeeded(
      autoStandEnabled: true,
      autoStandMinute: 10,
      autoSitMinute: 15,
      isUserActive: true
    )

    await standExpectation.fulfillment(within: .seconds(10))
  }

  @Test
  func shouldTriggerSit() async {
    let sitExpectation = Expectation()
    let autoStand = PeriodicAutoStand(
      settings: Settings(),
      stand: { Issue.record("Should not fire stand") },
      sit: { sitExpectation.fulfill() },
      currentTimeProvider: MockTimeProvider(simulatedDate: .todayAt(hour: 10, minute: 15))
    )

    autoStand.adjustHeightIfNeeded(
      autoStandEnabled: true,
      autoStandMinute: 10,
      autoSitMinute: 15,
      isUserActive: true
    )

    try? await Task.sleep(for: .seconds(2))

    await sitExpectation.fulfillment(within: .seconds(10))
  }

  @Test
  func shouldNotTriggerSitOrStandWrongTime() async {
    let eventFiredExpectation = Expectation(expectedCount: 0)
    let autoStand = PeriodicAutoStand(
      settings: Settings(),
      stand: { eventFiredExpectation.fulfill() },
      sit: { eventFiredExpectation.fulfill() },
      currentTimeProvider: MockTimeProvider(simulatedDate: .todayAt(hour: 10, minute: 20))
    )

    autoStand.adjustHeightIfNeeded(
      autoStandEnabled: true,
      autoStandMinute: 10,
      autoSitMinute: 15,
      isUserActive: true
    )

    await eventFiredExpectation.fulfillment(within: .seconds(3))
  }

  @Test
  func shouldNotTriggerStandUserNotActive() async {
    let eventFiredExpectation = Expectation(expectedCount: 0)
    let autoStand = PeriodicAutoStand(
      settings: Settings(),
      stand: { eventFiredExpectation.fulfill() },
      sit: { eventFiredExpectation.fulfill() },
      currentTimeProvider: MockTimeProvider(simulatedDate: .todayAt(hour: 10, minute: 15))
    )

    autoStand.adjustHeightIfNeeded(
      autoStandEnabled: true,
      autoStandMinute: 10,
      autoSitMinute: 15,
      isUserActive: false
    )

    await eventFiredExpectation.fulfillment(within: .seconds(3))
  }
}

extension Date {
  public static func todayAt(hour: Int, minute: Int) -> Date {
    let calendar = Calendar.current
    var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
    dateComponents.hour = hour
    dateComponents.minute = minute
    dateComponents.second = 0
    dateComponents.timeZone = calendar.timeZone
    return calendar.date(from: dateComponents)!
  }
}

struct MockTimeProvider: CurrentTimeProvider {
  private let simulatedDate: Date

  init(simulatedDate: Date) {
    self.simulatedDate = simulatedDate
  }

  func now() -> Date {
    return simulatedDate
  }
}

struct FakeUserDefaultsProvider: UserDefaultsProvider {
  var userDefaults: UserDefaults {
    return UserDefaults(suiteName: "autoStandTests")!
  }
}
