import Cocoa
import Foundation
import SwiftUI

@Observable
/// Automatic clock time based stand/sit orchestrator, with macOS HID inactivity timeout -- so it is not moving the desk up and down when you are not at the computer
class PeriodicAutoStand {
  @ObservationIgnored
  var timer: Timer?

  let enabled: Bool
  let stand: () -> Void
  let sit: () -> Void
  var standMinuteMarker: Int
  var sitMinuteMarker: Int
  let inactivityTimeoutMinutes: Int
  let settings: Settings
  let currentTimeProvider: CurrentTimeProvider

  var nextSpan: (stand: Date, sit: Date)? {
    guard enabled else { return nil }

    let calendar = Calendar.current

    let now = currentTimeProvider.now()

    guard let nextStand = calendar.nextDate(after: now, matching: DateComponents(minute: standMinuteMarker), matchingPolicy: .strict) else {
      return nil
    }

    guard let nextSit = calendar.nextDate(after: nextStand, matching: DateComponents(minute: sitMinuteMarker), matchingPolicy: .strict) else {
      return nil
    }

    return (nextStand, nextSit)
  }

  init(settings: Settings, stand: @escaping () -> Void, sit: @escaping () -> Void, currentTimeProvider: CurrentTimeProvider = SystemTimeProvider()) {
    Log.app.debug("PeriodicAutoStand initialized.")
    self.settings = settings
    self.enabled = settings.autoStand.currentValue()
    self.standMinuteMarker = settings.autoStandMinute.currentValue()
    self.sitMinuteMarker = settings.autoSitMinute.currentValue()
    self.inactivityTimeoutMinutes = settings.autoStandInactivityTimeout.currentValue()
    self.stand = stand
    self.sit = sit
    self.currentTimeProvider = currentTimeProvider
    scheduleTimer()
  }

  private func scheduleTimer() {
    let now = currentTimeProvider.now()
    let calendar = Calendar.current

    guard let nextMinute = calendar.nextDate(after: now, matching: DateComponents(second: 0), matchingPolicy: .strict) else {
      return
    }

    let interval = nextMinute.timeIntervalSince(now)

    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
      self?.startRepeatingTimer()
    }
  }

  private func startRepeatingTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      self?.checkAndFireMethods()
    }

    checkAndFireMethods()
  }

  func adjustHeightIfNeeded(
    autoStandEnabled: Bool,
    autoStandMinute: Int,
    autoSitMinute: Int,
    isUserActive: Bool
  ) {
    let now = currentTimeProvider.now()
    let calendar = Calendar.current
    let minute = calendar.component(.minute, from: now)

    guard autoStandEnabled else { return }

    self.standMinuteMarker = autoStandMinute
    self.sitMinuteMarker = autoSitMinute

    switch minute {
    case sitMinuteMarker:
      if isUserActive {
        Log.app.debug("Triggering sit")
        sit()
      } else {
        Log.app.debug("User is not active, so skipping automatic sit.")
      }
    case standMinuteMarker:
      if isUserActive {
        Log.app.debug("Triggering stand")
        stand()
      } else {
        Log.app.debug("User is not active, so skipping automatic stand.")
      }
    default:
      break
    }
  }

  private func checkAndFireMethods() {
    adjustHeightIfNeeded(
      autoStandEnabled: enabled,
      autoStandMinute: settings.autoStandMinute.currentValue(),
      autoSitMinute: settings.autoSitMinute.currentValue(),
      isUserActive: isUserActive()
    )
  }

  private func isUserActive() -> Bool {
    return userLastActive() < Measurement<UnitDuration>(value: Double(inactivityTimeoutMinutes), unit: .minutes)
  }

  private func userLastActive() -> Measurement<UnitDuration> {
    let idleTimeSinceKeyDown = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
    let idleTimeSinceMouseMoved = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .mouseMoved)

    let idleTime = min(idleTimeSinceKeyDown, idleTimeSinceMouseMoved)

    return .init(value: idleTime, unit: .seconds)
  }
}
