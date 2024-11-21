import Combine
import Foundation
import Testing
import TestingExpectation

@testable import MakeMeStand

class PeriodicAutoStandTests {
  @Test
  func shouldTriggerStand() async {
    let standExpectation = Expectation()
    let autoStand = PeriodicAutoStand(
      settings: Settings(),
      stand: { standExpectation.fulfill() },
      sit: { Issue.record("Should not fire sit") }
    )

    let now: Date = .todayAt(hour: 10, minute: 10)

    autoStand.adjustHeightIfNeeded(
      now: now,
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
      sit: { sitExpectation.fulfill() }
    )

    let now: Date = .todayAt(hour: 10, minute: 15)

    autoStand.adjustHeightIfNeeded(
      now: now,
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
      sit: { eventFiredExpectation.fulfill() }
    )

    let now: Date = .todayAt(hour: 10, minute: 20)

    autoStand.adjustHeightIfNeeded(
      now: now,
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
      sit: { eventFiredExpectation.fulfill() }
    )

    let now: Date = .todayAt(hour: 10, minute: 15)

    autoStand.adjustHeightIfNeeded(
      now: now,
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
    return calendar.date(from: dateComponents)!
  }
}
