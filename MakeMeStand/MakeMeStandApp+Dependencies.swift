import BlueConnect
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
        ]))
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
