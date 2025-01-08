import Foundation
import ServiceManagement
import SwiftUI

struct MakeMeStandMenuBar: Scene {
  @Environment(IdasenLinakBleRemoteControl.self) var deskController
  @Environment(PeriodicAutoStand.self) var autostandController
  @State private var launchAtLogin = false
  @AppStorage(\.autoConnect) var autoConnect: Bool
  @AppStorage(\.autoStand) var autoStand: Bool
  @AppStorage(\.autoStandMinute) var autoStandMinute: Int
  @AppStorage(\.autoSitMinute) var autoSitMinute: Int
  @AppStorage(\.autoStandInactivityTimeout) var autoStandInactivityTimeout: Int
  @AppStorage(\.doubleTapSwitch) var doubleTapSwitch: Bool

  // always store inches, regardless of display
  @AppStorage(\.standingHeightIn) var standingHeightIn: Double
  @AppStorage(\.sittingHeightIn) var sittingHeightIn: Double
  @AppStorage(\.showHeightInMenuBar) var showHeightInMenuBar: Bool

  var menubarIconName: String {
    switch deskController.activeDeskState {
    case .connected:
      return "table.furniture.fill"
    case .disconnected:
      return "table.furniture"
    case .unknown:
      return "table.furniture"
    case .disconnecting:
      return "arrow.counterclockwise"
    case .connecting:
      return "arrow.clockwise"
    }
  }

  var standingHeightFormatted: String {
    Measurement<UnitLength>(value: standingHeightIn, unit: .inches).formattedPreserveUnit()
  }

  var sittingHeightFormatted: String {
    Measurement<UnitLength>(value: sittingHeightIn, unit: .inches).formattedPreserveUnit()
  }

  var currentHeight: Measurement<UnitLength> {
    if let currentHeight = deskController.activeDeskState.height {
      return currentHeight
    } else {
      return Measurement<UnitLength>(value: 0, unit: .inches)
    }
  }

  var currentHeightFormatted: String {
    if let currentHeight = deskController.activeDeskState.height {
      return currentHeight.converted(to: .inches).formattedPreserveUnit()
    } else {
      return "unknown"
    }
  }

  var body: some Scene {
    MenuBarExtra {
      if deskController.nearbyDesks.isEmpty {
        Text("None found")
      } else {
        let sorted = deskController.nearbyDesks.sorted {
          ($0.value.name ?? "") < ($1.value.name ?? "")
        }

        ForEach(sorted, id: \.key.uuidString) { item in
          if case .connected(let activeDesk, _, _, _, _) = deskController.activeDeskState,
            activeDesk.identifier.uuidString == item.key.uuidString
          {
            Menu("\(item.value.name ?? "Unknown") (Connected).  Height: \(currentHeightFormatted)") {
              Text("UUID: \(item.key.uuidString).")

              Divider()

              Button("Move up") {
                Task {
                  try await deskController.moveUp()
                }
              }

              Button("Move down") {
                Task {
                  try await deskController.moveDown()
                }
              }

              Button("Stop moving") {
                Task {
                  try await deskController.moveStop()
                }
              }

              Button(
                "Move to standing position: \(standingHeightFormatted)"
              ) {
                Task {
                  try await deskController.move(to: Measurement(value: standingHeightIn, unit: .inches))
                }
              }

              Button("Move to sitting position: \(sittingHeightFormatted)") {
                Task {
                  try await deskController.move(to: Measurement(value: sittingHeightIn, unit: .inches))
                }
              }

              Divider()

              Button("Disconnect") {
                Task.detached {
                  try await deskController.disconnect(item.value)
                }
              }
            }
          } else {
            Menu(item.value.name ?? "Unknown") {
              Text("Disconnected")

              Divider()

              Button("Connect") {
                Task.detached {
                  try await deskController.connect(item.value)
                }
              }
            }
          }
        }
      }

      if autoStand,
        let nextSpan = autostandController.nextSpan
      {
        Text(
          "Next automatic stand: \(nextSpan.stand.formatted(date: .omitted, time: .shortened))-\(nextSpan.sit.formatted(date: .omitted, time: .shortened)), if activity within \(autoStandInactivityTimeout) minutes"
        )
      }

      Divider()

      Menu("Settings") {
        Toggle("Auto Connect to first found desk (toggle)", isOn: $autoConnect)

        Toggle("Launch Make me Stand at Login (toggle)", isOn: $launchAtLogin)
          .onChange(of: launchAtLogin) { previousValue, newValue in
            if newValue, !previousValue {
              do {
                try SMAppService.mainApp.register()
                Log.app.debug("Registered for Launch at Login")
              } catch {
                Log.app.error("Failed to register: \(error)")
              }
            } else {
              do {
                try SMAppService.mainApp.unregister()
              } catch {
                Log.app.error("Failed to deregister: \(error)")
              }
              Log.app.debug("Unregistered from Launch at Login")
            }
          }
          .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
          }

        Toggle("Show desk height in menu bar", isOn: $showHeightInMenuBar)

        Toggle("Enable Double tap (switch) to stand/sit", isOn: $doubleTapSwitch)

        Section("Auto Stand") {
          Toggle("Automatic Stand (toggle)", isOn: $autoStand)

          Picker("Stand at minute of every hour", selection: $autoStandMinute) {
            ForEach(0..<12) { index in
              Text("\(index * 5)").tag(index * 5)
            }
          }

          Picker("Sit at minute of every hour", selection: $autoSitMinute) {
            ForEach(0..<12) { index in
              Text("\(index * 5)").tag(index * 5)
            }
          }

          Picker("Inactivity timeout (minutes)", selection: $autoStandInactivityTimeout) {
            ForEach(0..<12) { index in
              Text("\(index * 5)").tag(index * 5)
            }
          }

          Menu("Sitting Height: \(sittingHeightFormatted)") {
            Button("save current height as new sitting height") {
              sittingHeightIn = currentHeight.converted(to: .inches).value
            }
          }
          Menu("Standing Height: \(standingHeightFormatted)") {
            Button("save current height as new standing height") {
              standingHeightIn = currentHeight.converted(to: .inches).value
            }
          }
        }
      }

      Divider()
      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }.keyboardShortcut("q")
    } label: {
      Image(systemName: menubarIconName)
        .accessibilityLabel("Make Me Stand")

      if case .connected = deskController.activeDeskState,
        showHeightInMenuBar
      {
        Text(currentHeightFormatted)
      }
    }
  }
}
