import BlueConnect
import Combine
import CoreBluetooth

extension MakeMeStandApp {
  func initializeDependencies(container: DependencyContainer) {
    let settings = Settings()
    container.registerSingleton(type: Settings.self) { settings }

    let remoteControl = IdasenLinakBleRemoteControl(
      proxy: BleCentralManagerProxy(
        queue: .main,
        options: [
          CBCentralManagerOptionRestoreIdentifierKey: "MakeMeStandRestoreIdentifier"
        ]),
      shouldPinToLastDesk: { settings.pinToLastConnectedDesk.currentValue() },
      getLastConnectedDeskUUID: { settings.lastConnectedDeskUUID.currentValue() },
      saveLastConnectedDeskUUID: { (uuid: String) in settings.lastConnectedDeskUUID.save(uuid) })

    remoteControl.doubleTapPublisher
      .receive(on: DispatchQueue.main)
      .sink { direction in
        switch direction {
        case .down:
          if settings.doubleTapSwitch.currentValue() {
            Task {
              let sittingHeightIn = settings.sittingHeightIn.currentValue()
              try await remoteControl.move(to: Measurement(value: sittingHeightIn, unit: .inches))
            }
          }
        case .up:
          if settings.doubleTapSwitch.currentValue() {
            Task {
              let standingHeightIn = settings.standingHeightIn.currentValue()
              try await remoteControl.move(to: Measurement(value: standingHeightIn, unit: .inches))
            }
          }
        }
      }
      .store(in: &remoteControl.subscriptions)

    container.registerSingleton(type: IdasenLinakBleRemoteControl.self) { remoteControl }

    let autoStand = PeriodicAutoStand(
      settings: settings,
      stand: {
        Task {
          guard let deskController = container.resolve(type: IdasenLinakBleRemoteControl.self),
            let settings = container.resolve(type: Settings.self)
          else {
            fatalError("Some dependencies are missing")
          }

          try await deskController.move(to: Measurement(value: settings.standingHeightIn.currentValue(), unit: .inches))
        }
      },
      sit: {
        Task {
          guard let deskController = container.resolve(type: IdasenLinakBleRemoteControl.self),
            let settings = container.resolve(type: Settings.self)
          else {
            fatalError("Some dependencies are missing")
          }

          try await deskController.move(to: Measurement(value: settings.sittingHeightIn.currentValue(), unit: .inches))
        }
      })
    container.registerSingleton(type: PeriodicAutoStand.self) { autoStand }

    Task {
      try await startScanningForNearbyDesks(container: container)
    }
  }

  private func startScanningForNearbyDesks(container: DependencyContainer) async throws {
    guard let deskController = container.resolve(type: IdasenLinakBleRemoteControl.self),
      let settings = container.resolve(type: Settings.self)
    else {
      fatalError("Some dependencies are missing")
    }

    try await deskController.scanForNearbyDesks(autoConnectFirstFound: settings.autoConnect.currentValue())
  }
}
