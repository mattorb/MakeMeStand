import BlueConnect
import Combine
import Foundation
import Testing
import TestingExpectation  // for waiting on async work queued outside of direct control/callback

@testable import MakeMeStand

class IdasenLinakBleRemoteControlTests {
  var subscriptions: Set<AnyCancellable> = []
  let bleCentralManager: MockBleCentralManager
  let bleCentralManagerProxy: BleCentralManagerProxy
  let mockDeskPeripheral = MockBleDeskPeripheral(
    identifier: UUID(),
    name: "Desk 123",
    position: DeskPosition(rawPosition: 1778, rawSpeed: 100)
  )
  let deskRemoteControl: StandingDeskBleRemoteControllable

  init() {
    bleCentralManager = MockBleCentralManager(peripherals: [mockDeskPeripheral])
    bleCentralManagerProxy = BleCentralManagerProxy(centralManager: bleCentralManager)
    bleCentralManager.state = .poweredOn
    deskRemoteControl = IdasenLinakBleRemoteControl(proxy: bleCentralManagerProxy)
  }

  deinit {
    self.subscriptions = []
  }

  @Test
  func scanAutoConnectEnabled() async throws {
    let (state, discoveredDeviceName) = try await scan(autoconnect: true)

    guard case .connected = state else {
      Issue.record("not connected")
      return
    }

    // device in initializer for mock peripheral, should be the device found and connected
    #expect(discoveredDeviceName == self.mockDeskPeripheral.name)

    // The observable list of nearby desks should be ready by now, too
    #expect(deskRemoteControl.nearbyDesks.count == 1)
  }

  @Test
  func scanAutoConnectDisabled() async throws {
    let (state, _) = try await scan(autoconnect: false)

    guard case .unknown = state else {
      Issue.record("not connected")
      return
    }
  }

  @Test
  func readInitialDeskPosition() async throws {
    let (_, _) = try await scan(autoconnect: true)

    let height = try await deskRemoteControl.currentHeight()
    #expect(height == Measurement(value: 79.27999999999999, unit: .centimeters))
    #expect(height.converted(to: .inches) == Measurement(value: 31.212598425196845, unit: .inches))
  }

  @Test
  func moveToStandBasic() async throws {
    let scenario = MoveWritePositionNotifySeriesScenario(
      direction: .up,
      targetPositionOffset: Measurement(value: 5.0, unit: .inches),
      numberOfMoveCommandsExpected: 6,
      positionUpdatesBetweenMoveCommands: [
        [.init(rawPositionOffset: UInt16((1 * 254)), rawSpeed: 100)],
        [.init(rawPositionOffset: UInt16((2 * 254)), rawSpeed: 100)],
        [.init(rawPositionOffset: UInt16((3 * 254)), rawSpeed: 100)],
        [.init(rawPositionOffset: UInt16((4 * 254)), rawSpeed: 100)],
        [.init(rawPositionOffset: UInt16((5 * 254)), rawSpeed: 100)],
        [.init(rawPositionOffset: UInt16((6 * 254)), rawSpeed: 100)],
      ]
    )

    let (moveCommandCount, heightDelta) = try await simulate(scenario: scenario)

    #expect(moveCommandCount == scenario.numberOfMoveCommandsExpected)
    #expect(heightDelta == scenario.targetPositionOffset)
  }

  @Test
  func moveToSit() async throws {
    let scenario = MoveWritePositionNotifySeriesScenario(
      direction: .down,
      targetPositionOffset: Measurement(value: 5.0, unit: .inches),
      numberOfMoveCommandsExpected: 6,
      positionUpdatesBetweenMoveCommands: [
        [.init(rawPositionOffset: UInt16((1 * 254)), rawSpeed: -100)],
        [.init(rawPositionOffset: UInt16((2 * 254)), rawSpeed: -100)],
        [.init(rawPositionOffset: UInt16((3 * 254)), rawSpeed: -100)],
        [.init(rawPositionOffset: UInt16((4 * 254)), rawSpeed: -100)],
        [.init(rawPositionOffset: UInt16((5 * 254)), rawSpeed: -100)],
        [.init(rawPositionOffset: UInt16((6 * 254)), rawSpeed: -100)],
      ]
    )

    let (moveCommandCount, heightDelta) = try await simulate(scenario: scenario)

    #expect(moveCommandCount == scenario.numberOfMoveCommandsExpected)
    #expect(heightDelta == -1 * scenario.targetPositionOffset)
  }

  @Test
  /// Similar to real desk, there may be several position update notifications, after a move command is sent, but that should not affect the number of move commands sent to desk since those are  based on travel, speed, and time elapsed
  func moveToStandChatty() async throws {
    let scenario = MoveWritePositionNotifySeriesScenario(
      direction: .up,
      targetPositionOffset: Measurement(value: 5.0, unit: .inches),
      numberOfMoveCommandsExpected: 6,
      positionUpdatesBetweenMoveCommands: [
        [
          .init(rawPositionOffset: UInt16((0.3 * 254)), rawSpeed: 100),
          .init(rawPositionOffset: UInt16((0.6 * 254)), rawSpeed: 200),
          .init(rawPositionOffset: UInt16((1 * 254)), rawSpeed: 100),
        ],
        [
          .init(rawPositionOffset: UInt16((1.3 * 254)), rawSpeed: 100),
          .init(rawPositionOffset: UInt16((1.5 * 254)), rawSpeed: 200),
          .init(rawPositionOffset: UInt16((1.6 * 254)), rawSpeed: 220),
          .init(rawPositionOffset: UInt16((2 * 254)), rawSpeed: 100),
        ],
        [
          .init(rawPositionOffset: UInt16((2.3 * 254)), rawSpeed: 100),
          .init(rawPositionOffset: UInt16((2.6 * 254)), rawSpeed: 200),
          .init(rawPositionOffset: UInt16((3 * 254)), rawSpeed: 100),
        ],
        [
          .init(rawPositionOffset: UInt16((3.3 * 254)), rawSpeed: 100),
          .init(rawPositionOffset: UInt16((3.6 * 254)), rawSpeed: 200),
          .init(rawPositionOffset: UInt16((4 * 254)), rawSpeed: 100),
        ],
        [
          .init(rawPositionOffset: UInt16((4.3 * 254)), rawSpeed: 100),
          .init(rawPositionOffset: UInt16((4.6 * 254)), rawSpeed: 200),
          .init(rawPositionOffset: UInt16((5 * 254)), rawSpeed: 100),
        ],
        [
          .init(rawPositionOffset: UInt16((5.3 * 254)), rawSpeed: 100),
          .init(rawPositionOffset: UInt16((5.6 * 254)), rawSpeed: 200),
          .init(rawPositionOffset: UInt16((6 * 254)), rawSpeed: 100),
        ],
      ]
    )

    let (moveCommandCount, heightDelta) = try await simulate(scenario: scenario)

    #expect(moveCommandCount == scenario.numberOfMoveCommandsExpected)
    #expect(heightDelta == scenario.targetPositionOffset)
  }

  @Test
  func moveToStandManuallyInterrupted() async throws {
    let scenario = MoveWritePositionNotifySeriesScenario(
      direction: .up,
      targetPositionOffset: Measurement(value: 5.0, unit: .inches),
      numberOfMoveCommandsExpected: 4,
      positionUpdatesBetweenMoveCommands: [
        [.init(rawPositionOffset: UInt16((1 * 254)), rawSpeed: 100)],
        [.init(rawPositionOffset: UInt16((2 * 254)), rawSpeed: 100)],
        [.init(rawPositionOffset: UInt16((2.5 * 254)), rawSpeed: 0)],  // speed of zero == interrupted
        [],
      ]
    )

    let (moveCommandCount, heightDelta) = try await simulate(scenario: scenario)

    #expect(moveCommandCount == scenario.numberOfMoveCommandsExpected)
    #expect(heightDelta == Measurement(value: 2.5, unit: .inches))  // interrupted at halfway point
  }

  @Test(.disabled("Not implemented yet. would need to add delay support to simulate+scenario"))
  func moveToStandWeightedSlow() {
  }

  struct MoveWritePositionNotifySeriesScenario {
    enum MoveDirection {
      case up
      case down
    }

    struct PositionChangeInstance {
      let rawPositionOffset: UInt16
      let rawSpeed: Int16/// signed, positive is moving up, negative is moving down
    }

    let direction: MoveDirection
    let targetPositionOffset: Measurement<UnitLength>
    let numberOfMoveCommandsExpected: UInt

    /// Each move command issued to desk may result in one or more position/speed characteristic update notifications over time
    let positionUpdatesBetweenMoveCommands: [[PositionChangeInstance]]
  }

  /// Simulate series of position characteristic notifications on each move characteristic write, returning move command count and final height delta
  private func simulate(scenario: MoveWritePositionNotifySeriesScenario) async throws -> (moveCommandCount: Int, heightDelta: Measurement<UnitLength>?)
  {
    guard scenario.positionUpdatesBetweenMoveCommands.count == scenario.numberOfMoveCommandsExpected else {
      Issue.record("there must be position update series (even if empty) matching the number of move commands, to define the scenario")
      return (moveCommandCount: 0, heightDelta: nil)
    }

    let state = try await scan(autoconnect: true).state

    guard case .connected(_, _, let deskPositionProxy, let deskMoveProxy, let startingHeight) = state,
      let deskPositionProxy,
      let deskMoveProxy
    else {
      Issue.record("no proxy avaiable")
      return (moveCommandCount: 0, heightDelta: nil)
    }

    let targetHeight = scenario.direction == .up ? startingHeight + scenario.targetPositionOffset : startingHeight - scenario.targetPositionOffset
    let movementCommandExpectation = Expectation(expectedCount: scenario.numberOfMoveCommandsExpected)
    var moveCommandCount: Int = 0

    let startingRawDeskPosition = try await deskPositionProxy.read(cachePolicy: .never, timeout: .seconds(15))

    // every time a move command is sent to the desk, simulate desk actuators adjusting height and BLE position/speed characteristic (which notifies)
    deskMoveProxy.didWriteValuePublisher
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          moveCommandCount += 1
          movementCommandExpectation.fulfill()

          guard scenario.positionUpdatesBetweenMoveCommands.indices.contains(moveCommandCount - 1) else {
            return
          }

          let positionSeries = scenario.positionUpdatesBetweenMoveCommands[moveCommandCount - 1]

          for positionNotify in positionSeries {
            let nextRawPosition =
              switch scenario.direction {
              case .up: startingRawDeskPosition.rawPosition + positionNotify.rawPositionOffset
              case .down: startingRawDeskPosition.rawPosition - positionNotify.rawPositionOffset
              }

            let nextPosition = DeskPosition(
              rawPosition: nextRawPosition,
              rawSpeed: positionNotify.rawSpeed
            )

            self.mockDeskPeripheral.updateValueInternal(nextPosition.data(), for: self.mockDeskPeripheral.positionService.characteristics!.first!)
          }
        }
      ).store(in: &subscriptions)

    try await deskRemoteControl.move(to: targetHeight)
    try await Task.sleep(for: .seconds(1.0))  // give the value read/notify queue time to process...ick.

    await movementCommandExpectation.fulfillment(within: .seconds(10))
    #expect(moveCommandCount == scenario.numberOfMoveCommandsExpected)

    guard case .connected(_, _, _, _, let lastSeenHeight) = deskRemoteControl.activeDeskState else {
      Issue.record("No height seen recently")
      return (moveCommandCount: moveCommandCount, heightDelta: nil)
    }

    let heightDeltaTo4DecimalPlaces =
      Measurement<UnitLength>(
        value: (lastSeenHeight.converted(to: .inches).value - startingHeight.converted(to: .inches).value).rounded(
          toDecimalPlaces: 4),
        unit: .inches
      )

    return (moveCommandCount: moveCommandCount, heightDelta: heightDeltaTo4DecimalPlaces)
  }

  private func scan(autoconnect: Bool) async throws -> (state: BleDeskConnectionState, deviceName: String?) {
    let connectExpectation = Expectation()
    var discoveredDeviceName: String?

    try await deskRemoteControl.scanForNearbyDesks(autoConnectFirstFound: autoconnect)

    bleCentralManagerProxy.didConnectPublisher
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { peripheral in
          discoveredDeviceName = peripheral.name
          connectExpectation.fulfill()
        }
      ).store(in: &subscriptions)

    if autoconnect {
      await connectExpectation.fulfillment(within: .seconds(10))

      try await Task.sleep(for: .seconds(1.0))  // give the value read/notify queue time to process...ick.
    }

    return (deskRemoteControl.activeDeskState, discoveredDeviceName)
  }
}

extension Double {
  func rounded(toDecimalPlaces places: Int = 10) -> Double {
    let multiplier = pow(10, Double(places))
    return (self * multiplier).rounded(.toNearestOrAwayFromZero) / multiplier
  }
}
