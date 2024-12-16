@preconcurrency import CoreBluetooth
import MakeMeStand

@testable import BlueConnect

class MockBleCentralManager: BleCentralManager, @unchecked Sendable {
  weak var centraManagerDelegate: BleCentralManagerDelegate?

  var authorization: CBManagerAuthorization { .allowedAlways }
  var isScanning: Bool = false
  var state: CBManagerState = .poweredOff {
    didSet {
      queue.async { [weak self] in
        guard let self else { return }
        disconnectAllPeripheralsIfNotPoweredOn()
        centraManagerDelegate?.bleCentralManagerDidUpdateState(self)
      }
    }
  }

  // MARK: - Internal properties
  let mutex = RecursiveMutex()
  var peripherals: [BlePeripheral] = []
  var scanTimer: DispatchSourceTimer?
  var scanCounter: Int = 0

  var scanNotifyInterval: TimeInterval

  lazy var queue: DispatchQueue = DispatchQueue.global(qos: .background)

  // MARK: - Initialization

  init(peripherals: [BlePeripheral], scanNotifyInterval: TimeInterval) {
    self.peripherals = peripherals
    self.scanNotifyInterval = scanNotifyInterval
  }

  // MARK: - Interface

  func connect(_ peripheral: BlePeripheral, options: [String: Any]?) {
    guard peripheral.state != .connecting else { return }
    guard let mockPeripheral = peripheral as? MockBleDeskPeripheral else { return }
    // move to connecting state before going async
    mockPeripheral.state = .connecting
    queue.async { [weak self] in
      guard let self else { return }
      mutex.lock()
      defer { mutex.unlock() }
      guard state == .poweredOn else {
        mockPeripheral.state = .disconnected
        centraManagerDelegate?.bleCentralManager(
          self,
          didFailToConnect: mockPeripheral,
          error: MockBleError.bluetoothIsOff)
        return
      }
      @Sendable func _connectInternal() {
        mutex.lock()
        defer { mutex.unlock() }
        guard state == .poweredOn else { return }
        guard mockPeripheral.state == .connecting else { return }
        mockPeripheral.state = .connected
        centraManagerDelegate?.bleCentralManager(self, didConnect: mockPeripheral)
      }
      _connectInternal()
    }
  }

  func cancelConnection(_ peripheral: BlePeripheral) {
    guard peripheral.state != .disconnecting else { return }
    guard let mockPeripheral = peripheral as? MockBleDeskPeripheral else { return }
    mockPeripheral.state = .disconnecting
    queue.async { [weak self] in
      guard let self else { return }
      mutex.lock()
      defer { mutex.unlock() }
      let error: Error?
      if state != .poweredOn {
        error = MockBleError.bluetoothIsOff
      } else {
        error = nil
      }
      @Sendable func _disconnectInternal() {
        mutex.lock()
        defer { mutex.unlock() }
        guard mockPeripheral.state == .disconnecting else { return }
        mockPeripheral.state = .disconnected
        centraManagerDelegate?.bleCentralManager(
          self,
          didDisconnectPeripheral: mockPeripheral,
          error: error)
      }

      _disconnectInternal()
    }
  }

  func retrievePeripherals(withIds identifiers: [UUID]) -> [BlePeripheral] {
    mutex.lock()
    defer { mutex.unlock() }
    return peripherals.filter { peripheral in
      identifiers.contains { $0 == peripheral.identifier }
    }
  }

  func retrieveConnectedPeripherals(withServiceIds serviceUUIDs: [CBUUID]) -> [BlePeripheral] {
    mutex.lock()
    defer { mutex.unlock() }
    return peripherals.filter { peripheral in
      guard peripheral.state == .connected else { return false }
      guard let services = peripheral.services else { return false }
      guard services.map({ $0.uuid }).contains(oneOf: serviceUUIDs) else { return false }
      return true
    }
  }

  func scanForPeripherals(withServices: [CBUUID]?, options: [String: Any]?) {
    mutex.lock()
    defer { mutex.unlock() }
    isScanning = true
    scanCounter = 0
    scanTimer?.cancel()
    scanTimer = DispatchSource.makeTimerSource(queue: .global())
    scanTimer?.schedule(deadline: .now() + scanNotifyInterval, repeating: scanNotifyInterval)
    scanTimer?.setEventHandler { [weak self] in
      guard let self else { return }
      scanInterval()
    }
    scanTimer?.resume()
  }

  func stopScan() {
    mutex.lock()
    defer { mutex.unlock() }
    isScanning = false
    scanCounter = 0
    scanTimer?.cancel()
    scanTimer = nil
  }

  // MARK: - Internals

  private func disconnectAllPeripheralsIfNotPoweredOn() {
    mutex.lock()
    defer { mutex.unlock() }
    guard state != .poweredOn else { return }
    for peripheral in peripherals {
      guard let mockPeripheral = peripheral as? MockBleDeskPeripheral else { continue }
      mockPeripheral.state = .disconnected
    }
  }

  private func scanInterval() {
    mutex.lock()
    defer { mutex.unlock() }
    guard !peripherals.isEmpty else { return }
    scanCounter += 1
    let peripheral = peripherals[scanCounter % peripherals.count]
    var advertisementData: [String: Any] = [:]
    advertisementData[CBAdvertisementDataIsConnectable] = true
    if let name = peripheral.name {
      advertisementData[CBAdvertisementDataLocalNameKey] = name
    }
    centraManagerDelegate?.bleCentralManager(
      self,
      didDiscover: peripheral,
      advertisementData: .init(advertisementData),
      rssi: Int.random(in: (-90)...(-50)))
  }
}

extension RangeReplaceableCollection {
  func contains<S: Sequence>(oneOf sequence: S) -> Bool where S.Element == Element, Element: Hashable {
    var set = Set(sequence)
    let intersection = filter { !set.insert($0).inserted }
    return !intersection.isEmpty
  }
}
