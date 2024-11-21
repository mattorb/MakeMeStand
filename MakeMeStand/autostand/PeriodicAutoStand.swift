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

  init(settings: Settings, stand: @escaping () -> Void, sit: @escaping () -> Void) {
    Log.app.debug("PeriodicAutoStand initialized.")
    self.settings = settings
    self.enabled = settings.autoStand.currentValue()
    self.standMinuteMarker = settings.autoStandMinute.currentValue()
    self.sitMinuteMarker = settings.autoSitMinute.currentValue()
    self.inactivityTimeoutMinutes = settings.autoStandInactivityTimeout.currentValue()
    self.stand = stand
    self.sit = sit
    scheduleTimer()
  }

  private func scheduleTimer() {
    let now = Date()
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
    now: Date = Date(),
    autoStandEnabled: Bool,
    autoStandMinute: Int,
    autoSitMinute: Int,
    isUserActive: Bool
  ) {
    let calendar = Calendar.current
    let minute = calendar.component(.minute, from: now)

    guard enabled else { return }

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