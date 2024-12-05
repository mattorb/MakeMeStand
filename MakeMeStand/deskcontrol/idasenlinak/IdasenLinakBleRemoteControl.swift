import BlueConnect
import Combine
import CoreBluetooth
import Foundation

@Observable
class IdasenLinakBleRemoteControl: StandingDeskBleRemoteControllable {
  var nearbyDesks: [UUID: BlePeripheral] = [:]
  var activeDeskState: BleDeskConnectionState = .unknown

  @ObservationIgnored
  let centralManagerProxy: BleCentralManagerProxy

  @ObservationIgnored
  var subscriptions: Set<AnyCancellable> = []
  @ObservationIgnored
  var automationSubscription: AnyCancellable?
  
  @ObservationIgnored
  private var doubleTapDetector: IdasenLinakBleDoubleTapSwitchDetector? // only after connect
  @ObservationIgnored
  var doubleTapPublisher: PassthroughSubject<SwitchMoveDirection, Never> = .init()

  init(proxy: BleCentralManagerProxy) {
    centralManagerProxy = proxy

    centralManagerProxy.didConnectPublisher
      .receive(on: DispatchQueue.main)
      .sink { peripheral in
        Log.app.debug("peripheral '\(peripheral.identifier)' connected")
      }
      .store(in: &subscriptions)

    centralManagerProxy.didFailToConnectPublisher
      .receive(on: DispatchQueue.main)
      .sink { peripheral, error in
        Log.app.debug(
          "peripheral '\(peripheral.identifier)' failed to connect with error: \(error)"
        )
      }
      .store(in: &subscriptions)
  }

  /// Start Scan, returns immediately.   Results land in ``nearbyDesks`` as they are found
  func scanForNearbyDesks(autoConnectFirstFound: Bool) async throws {
    do {
      try await centralManagerProxy.waitUntilReady()

      centralManagerProxy.scanForPeripherals(timeout: .seconds(30))
        .receive(on: DispatchQueue.main)
        .sink(
          receiveCompletion: { completion in
            switch completion {
            case .finished:
              Log.app.debug("peripheral scan completed successfully")
            case .failure(let error):
              Log.app.error("Error scanning for peripherals: \(error.localizedDescription)")
            }
          },
          receiveValue: { peripheral, advertisementsData, rssi in
            let name = peripheral.name ?? peripheral.identifier.uuidString

            let deskNamePattern = #/[Dd]esk [0-9]+/#

            if name.contains(deskNamePattern),
              !self.nearbyDesks.contains(where: {
                $0.value.identifier == peripheral.identifier
              })
            {
              Log.app.debug(
                "Discovered peripheral: \(name), connectable? \(advertisementsData.isConnectable), info: \(String(describing: advertisementsData.serviceUUIDs))"
              )
              self.nearbyDesks[peripheral.identifier] = peripheral

              if autoConnectFirstFound {
                if case .unknown = self.activeDeskState {
                  Task {
                    Log.app.debug("Auto connecting to \(name)")
                    try await self.connect(peripheral)
                  }
                }
              }
            } else {
              //              logger.debug("Ignoring Discovered peripheral: \(peripheral.identifier)")
            }
          }
        )
        .store(in: &subscriptions)
    } catch {
      Log.app.error("Error scanning for peripherals: \(error)")
      logState()
    }
  }

  private func logState() {
    switch self.centralManagerProxy.state {
    case .poweredOn:
      // Bluetooth is ready, start scanning
      Log.app.debug("It's on")
    case .poweredOff:
      Log.app.debug("Bluetooth is powered off")
    case .resetting:
      Log.app.debug("Bluetooth is resetting")
    case .unauthorized:
      Log.app.debug("Bluetooth is unauthorized")
    case .unsupported:
      Log.app.debug("Bluetooth is unsupported on this device")
    case .unknown:
      Log.app.debug("Bluetooth state is unknown")
    @unknown default:
      Log.app.debug("Unknown Bluetooth state")
    }
  }

  func connect(_ desk: BlePeripheral) async throws {
    do {
      Task { @MainActor in
        activeDeskState = .connecting
      }
      centralManagerProxy.stopScan()
      try await centralManagerProxy.waitUntilReady()
      try await centralManagerProxy.connect(
        peripheral: desk,
        options: nil,
        timeout: .seconds(60))

      Log.app.debug("Connected to desk \(desk.name ?? desk.identifier.uuidString)")

      let peripheralProxy = BlePeripheralProxy(peripheral: desk)
      let deskPositionProxy = DeskPositionProxy(peripheralProxy: peripheralProxy)
      let deskMoveCommandProxy = DeskMoveCommandProxy(peripheralProxy: peripheralProxy)

      // state & ensure these are all retained
      activeDeskState = .connected(desk, peripheralProxy, deskPositionProxy, deskMoveCommandProxy, Measurement(value: 0, unit: .inches))

      doubleTapDetector = IdasenLinakBleDoubleTapSwitchDetector(deskPositionProxy: deskPositionProxy)

      doubleTapDetector?.onDoubleTapPublisher
        .receive(on: DispatchQueue.main)
        .sink {
          self.doubleTapPublisher.send($0)
        }
        .store(in: &subscriptions)

      let height = try await currentHeight()

      try await deskPositionProxy.discover(timeout: .seconds(10))  // cache discovery so we can query quick
      try await deskMoveCommandProxy.discover(timeout: .seconds(10))  // cache discovery so we can issue commands quickly

      deskPositionProxy.didUpdateNotificationStatePublisher
        .receive(on: DispatchQueue.main)
        .sink { enabled in
          Log.app.debug("desk position notification enabled: \(enabled)")
        }
        .store(in: &subscriptions)

      deskPositionProxy.didUpdateValuePublisher
        .receive(on: DispatchQueue.main)
        .sink { deskPosition in
          Log.app.debug("position changed, app listener: \(deskPosition.height.converted(to: .inches)), speed: \(deskPosition.rawSpeed)")

          if case .connected(let blePeripheral, let blePeripheralProxy, let deskPositionProxy, let deskMoveProxy, _) = self.activeDeskState {
            self.activeDeskState = .connected(blePeripheral, blePeripheralProxy, deskPositionProxy, deskMoveProxy, deskPosition.height)
          }
        }
        .store(in: &subscriptions)

      try await deskPositionProxy.setNotify(enabled: true, timeout: .seconds(10))

      Log.app.debug("Desk height is \(height.converted(to: .inches))")

      Task { @MainActor in
        activeDeskState = .connected(desk, peripheralProxy, deskPositionProxy, deskMoveCommandProxy, height.converted(to: .inches))
      }
    } catch {
      Log.app.error("desk peripheral connection failed with error: \(error)")
    }
  }

  func disconnect(_ desk: BlePeripheral) async throws {
    Task { @MainActor in
      activeDeskState = .disconnecting
    }

    do {
      try await centralManagerProxy.waitUntilReady()
      try await centralManagerProxy.disconnect(peripheral: desk)
      Task { @MainActor in
        activeDeskState = .disconnected
      }
      Log.app.debug("desk peripheral '\(desk.name ?? desk.identifier.uuidString)' disconnected")
    } catch {
      Log.app.error("desk peripheral disconnection failed with error: \(error)")
    }
  }

  func move(to desiredHeight: Measurement<UnitLength>) async throws {
    if case .connected(_, _, let deskPositionProxy, _, _) = activeDeskState,
      let deskPositionProxy
    {
      let originalDeskPosition = try await deskPositionProxy.read(cachePolicy: .never, timeout: .seconds(15))
      let currentHeight = originalDeskPosition.height

      Log.app.debug("Request to move to height \(desiredHeight.converted(to: .inches)), current height = \(currentHeight.converted(to: .inches))")

      let movingUp = desiredHeight > originalDeskPosition.height
      let movingDown = desiredHeight < originalDeskPosition.height

      let distanceOffsetCm: Float = 0.5  // expected movement when full speed
      let minimumDurationBetweenIssuingMoveCommands: TimeInterval = 0.5
      let minimumTravelBetweenIssuingMoveCommands: Double = 0.5  // Make sure it's moved at least 0.75cm before moving again
      var lastMoveTime = Date().addingTimeInterval(-minimumDurationBetweenIssuingMoveCommands)
      var previousPosition: DeskPosition = originalDeskPosition
      var expectedLandingPositionIfStopped: Measurement<UnitLength> = originalDeskPosition.height.converted(to: .centimeters)

      // this queue handles nudging the move to the desired height until it arrives or passes, or stops unexpectedly
      automationSubscription = deskPositionProxy.didUpdateValuePublisher
        .receive(on: DispatchQueue.main)
        .sink { deskPosition in
          Log.app.debug(
            "position value updater in move listener: \(deskPosition.height.converted(to: .inches)), speed: \(deskPosition.rawSpeed)")

          let timeSinceLastMove = lastMoveTime.distance(to: Date())
          let distanceTraveledSincePreviousPosition = abs(
            (previousPosition.height.converted(to: .centimeters).value + minimumTravelBetweenIssuingMoveCommands)
              - deskPosition.height.converted(to: .centimeters).value)

          let didPassTarget = (movingUp && deskPosition.height >= desiredHeight) || (movingDown && deskPosition.height <= desiredHeight)
          let minimumTimeElapsedSincePreviousMoveCommand = timeSinceLastMove > minimumDurationBetweenIssuingMoveCommands
          let minimumDistanceTraveledSincePreviousMoveCommand = distanceTraveledSincePreviousPosition >= minimumTravelBetweenIssuingMoveCommands
          let alreadyMoving = movingUp ? deskPosition.rawSpeed >= 0 : deskPosition.rawSpeed <= 0
          let manuallyStopped = !minimumTimeElapsedSincePreviousMoveCommand && deskPosition.rawSpeed == 0

          expectedLandingPositionIfStopped =
            movingUp
            ? (deskPosition.height + Measurement(value: Double(distanceOffsetCm), unit: .centimeters))
            : (deskPosition.height - Measurement(value: Double(distanceOffsetCm), unit: .centimeters))

          let aboutToPassTarget = movingUp ? expectedLandingPositionIfStopped > desiredHeight : expectedLandingPositionIfStopped < desiredHeight

          if (aboutToPassTarget || didPassTarget) || manuallyStopped {
            Task {
              Log.app.debug(
                "atpt = \(aboutToPassTarget), dpt = \(didPassTarget), ms = \(manuallyStopped), Reached or passed destination or manually stopped, stopping (expected landing: \(expectedLandingPositionIfStopped) vs desiredHeight \(desiredHeight)"
              )
              self.automationSubscription?.cancel()
              try await self.moveStop()
            }
          } else if movingUp || movingDown,
            alreadyMoving,
            minimumTimeElapsedSincePreviousMoveCommand,
            minimumDistanceTraveledSincePreviousMoveCommand,
            !aboutToPassTarget
          {
            Task {
              lastMoveTime = Date()
              Log.app.debug("Issuing \(movingUp ? "Move Up" : "Move down") command")
              previousPosition = deskPosition

              if movingUp {
                try await self.moveUp()
              } else {
                try await self.moveDown()
              }
            }
          }
        }

      // kick off the first one to get things going
      if movingUp {
        Task {
          try await self.moveUp()
        }
      } else if movingDown {
        Task {
          try await self.moveDown()
        }
      }
    }
  }

  func moveUp() async throws {
    if case .connected(_, _, _, let deskMoveCommandProxy, _) = activeDeskState,
      let deskMoveCommandProxy
    {
      try await deskMoveCommandProxy.write(value: .up, timeout: .seconds(15))
      let height = try await currentHeight()
      Log.app.debug("Desk height is \(height.converted(to: .inches))")
    }
  }

  func moveDown() async throws {
    if case .connected(_, _, _, let deskMoveCommandProxy, _) = activeDeskState,
      let deskMoveCommandProxy
    {
      try await deskMoveCommandProxy.write(value: .down, timeout: .seconds(15))
      let height = try await currentHeight()
      Log.app.debug("Desk height is \(height.converted(to: .inches))")
    }
  }

  func moveStop() async throws {
    if case .connected(_, _, _, let deskMoveCommandProxy, _) = activeDeskState,
      let deskMoveCommandProxy
    {
      try await deskMoveCommandProxy.write(value: .stop, timeout: .seconds(15))
      let height = try await currentHeight()
      Log.app.debug("Desk height is \(height.converted(to: .inches))")
    }
  }

  func currentHeight() async throws -> Measurement<UnitLength> {
    if case .connected(_, _, let deskPositionProxy, _, _) = activeDeskState,
      let deskPositionProxy
    {
      let deskPosition = try await deskPositionProxy.read(cachePolicy: .never, timeout: .seconds(15))
      return deskPosition.height
    } else {
      return Measurement(value: 0, unit: .centimeters)
    }
  }
}
