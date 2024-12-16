import BlueConnect
import Combine
import Foundation
import Testing
import TestingExpectation  // for waiting on async work queued outside of direct control/callback

@testable import MakeMeStand

class DoubleTapSwitchTests {
  var subscriptions: Set<AnyCancellable> = []
  let bleCentralManager: MockBleCentralManager
  let bleCentralManagerProxy: BleCentralManagerProxy
  let mockDeskPeripheral = MockBleDeskPeripheral(
    disableIntervalNotify: true,
    identifier: UUID(),
    name: "Desk 123",
    position: DeskPosition(rawPosition: 1778, rawSpeed: 100)
  )
  let deskRemoteControl: StandingDeskBleRemoteControllable
  let scanNotifyInterval = 0.1

  init() {
    bleCentralManager = MockBleCentralManager(peripherals: [mockDeskPeripheral], scanNotifyInterval: scanNotifyInterval)
    bleCentralManagerProxy = BleCentralManagerProxy(centralManager: bleCentralManager)
    bleCentralManager.state = .poweredOn
    deskRemoteControl = IdasenLinakBleRemoteControl(proxy: bleCentralManagerProxy)
  }

  deinit {
    self.subscriptions = []
  }

  @Test
  func detectUpDoubleTap() async throws {
    let expectUp = Expectation(expectedCount: 1)

    let result = try await simulate(
      positionUpdates: [
        .init(rawPosition: 1000 + UInt16((1 * 40)), rawSpeed: 80),
        .init(rawPosition: 1000 + UInt16((2 * 40)), rawSpeed: 0),
        .init(rawPosition: 1000 + UInt16((3 * 40)), rawSpeed: 120),
        .init(rawPosition: 1000 + UInt16((4 * 40)), rawSpeed: 0),
      ], upExpectation: expectUp)

    await expectUp.fulfillment(within: .seconds(5))

    #expect(result == .up)
  }

  @Test
  func detectDownDoubleTap() async throws {
    let expectDown = Expectation(expectedCount: 1)

    let result = try await simulate(
      positionUpdates: [
        .init(rawPosition: 1000 + UInt16((1 * 40)), rawSpeed: -90),
        .init(rawPosition: 1000 - UInt16((2 * 40)), rawSpeed: 0),
        .init(rawPosition: 1000 - UInt16((3 * 40)), rawSpeed: -130),
        .init(rawPosition: 1000 - UInt16((4 * 40)), rawSpeed: 0),
      ], downExpectation: expectDown)

    #expect(result == .down)
  }

  @Test
  func ignoreSteadyMovement() async throws {
    let expectNothing = Expectation(expectedCount: 0)

    let result = try await simulate(
      positionUpdates: [
        .init(rawPosition: 1000 + UInt16((1 * 40)), rawSpeed: 80),
        .init(rawPosition: 1000 + UInt16((2 * 40)), rawSpeed: 90),
        .init(rawPosition: 1000 + UInt16((3 * 40)), rawSpeed: 90),
      ],
      upExpectation: expectNothing,
      downExpectation: expectNothing
    )

    await expectNothing.fulfillment(within: .seconds(5))

    #expect(result == .none)
  }

  @Test
  func ignoreLanded() async throws {
    let expectNothing = Expectation(expectedCount: 0)

    let result = try await simulate(
      positionUpdates: [
        .init(rawPosition: 1000 + UInt16((1 * 40)), rawSpeed: 120),
        .init(rawPosition: 1000 + UInt16((2 * 40)), rawSpeed: 80),
        .init(rawPosition: 1000 + UInt16((3 * 40)), rawSpeed: 0),
      ],
      upExpectation: expectNothing,
      downExpectation: expectNothing
    )

    await expectNothing.fulfillment(within: .seconds(5))

    #expect(result == .none)
  }

  @Test
  func ignoreStillMoving() async throws {
    let expectNothing = Expectation(expectedCount: 0)

    let result = try await simulate(
      positionUpdates: [
        .init(rawPosition: 1000 + UInt16((1 * 40)), rawSpeed: 0),
        .init(rawPosition: 1000 + UInt16((2 * 40)), rawSpeed: 80),
        .init(rawPosition: 1000 + UInt16((3 * 40)), rawSpeed: 120),
      ],
      upExpectation: expectNothing,
      downExpectation: expectNothing
    )

    await expectNothing.fulfillment(within: .seconds(5))

    #expect(result == .none)
  }

  private func simulate(
    positionUpdates: [DeskPosition], upExpectation: TestingExpectation.Expectation? = nil, downExpectation: TestingExpectation.Expectation? = nil
  ) async throws
    -> SwitchMoveDirection?
  {
    let state = try await scan(autoconnect: true).state

    guard case .connected(_, _, let deskPositionProxy, _, _) = state,
      let deskPositionProxy
    else {
      Issue.record("no proxy avaiable")
      return .none
    }

    var result: SwitchMoveDirection? = nil

    let thresholdSeconds = 0.2
    let doubleTapDetector = IdasenLinakBleDoubleTapSwitchDetector(deskPositionProxy: deskPositionProxy, doubleTapThresholdSeconds: thresholdSeconds)

    doubleTapDetector.onDoubleTapPublisher
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { direction in
          switch direction {
          case .down:
            result = .down
            downExpectation?.fulfill()
          case .up:
            result = .up
            upExpectation?.fulfill()
          }
        }
      ).store(in: &subscriptions)

    let positionCharacteristic = mockDeskPeripheral.positionService.characteristics!.first!

    for position in positionUpdates {
      mockDeskPeripheral.updateValueInternal(position.data(), for: positionCharacteristic, withNotify: true)
    }

    await withCheckedContinuation { continuation in
      DispatchQueue.main.async(flags: .barrier) {
        continuation.resume()
      }
    }

    try await Task.sleep(for: .seconds(thresholdSeconds + 0.1))  // double tap detection threshold + 0.1 for Combine -- ick

    return result
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

      try await Task.sleep(for: .seconds(scanNotifyInterval))  // give scan
    }

    return (deskRemoteControl.activeDeskState, discoveredDeviceName)
  }
}
