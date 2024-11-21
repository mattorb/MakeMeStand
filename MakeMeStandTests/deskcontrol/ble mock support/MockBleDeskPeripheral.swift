@preconcurrency import CoreBluetooth
import MakeMeStand

@testable import BlueConnect

class MockBleDeskPeripheral: BlePeripheral, @unchecked Sendable {
  let identifier: UUID
  var name: String? {
    didSet {
      queue.async { [weak self] in
        guard let self else { return }
        peripheralDelegate?.blePeripheralDidUpdateName(self)
      }
    }
  }
  var services: [CBService]? = nil
  var state: CBPeripheralState = .disconnected {
    didSet {
      if state == .connected {
        startNotify()
      } else {
        stopNotify()
      }
    }
  }

  weak var peripheralDelegate: BlePeripheralDelegate?
  var rssi: Int = -80

  private let position: DeskPosition
  private let mutex = RecursiveMutex()
  private var timer: DispatchSourceTimer?

  let positionService = CBMutableService(type: LinakBLEControllerDescriptor.PositionService.uuid, primary: false)
  let moveService = CBMutableService(type: LinakBLEControllerDescriptor.MoveService.uuid, primary: false)

  lazy var queue: DispatchQueue = DispatchQueue.global(qos: .background)

  // MARK: - Initialization

  init(
    identifier: UUID,
    name: String?,
    position: DeskPosition
  ) {
    self.identifier = identifier
    self.name = name
    self.position = position
  }

  // MARK: - Interface

  func discoverServices(_ serviceUUIDs: [CBUUID]?) {
    queue.async { [weak self] in
      guard let self else { return }
      mutex.lock()
      defer { mutex.unlock() }
      guard state == .connected else {
        peripheralDelegate?.blePeripheral(self, didDiscoverServices: MockBleError.peripheralNotConnected)
        return
      }
      @Sendable func _discoverServicesInternal() {
        mutex.lock()
        defer { mutex.unlock() }
        self.services = [positionService, moveService]  // discover them all
        peripheralDelegate?.blePeripheral(self, didDiscoverServices: nil)
      }

      _discoverServicesInternal()
    }
  }

  func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
    queue.async { [weak self] in
      guard let self else { return }
      mutex.lock()
      defer { mutex.unlock() }
      @Sendable func _discoverCharacteristicsInternal() {
        if service == positionService {
          discoverPositionServiceCharacteristics(characteristicUUIDs)
        } else if service == moveService {
          discoverMoveServiceCharacteristics(characteristicUUIDs)
        }
      }

      _discoverCharacteristicsInternal()
    }
  }

  func readValue(for characteristic: CBCharacteristic) {
    queue.async { [weak self] in
      guard let self else { return }

      mutex.lock()
      defer { mutex.unlock() }

      guard state == .connected else {
        peripheralDelegate?.blePeripheral(
          self,
          didUpdateValueFor: characteristic,
          error: MockBleError.peripheralNotConnected)
        return
      }
      guard characteristic.properties.contains(.read) else {
        peripheralDelegate?.blePeripheral(
          self,
          didUpdateValueFor: characteristic,
          error: MockBleError.operationNotSupported)
        return
      }
      guard let internalCharacteristic = findInternalMutableCharacteristic(characteristic) else {
        peripheralDelegate?.blePeripheral(
          self,
          didUpdateValueFor: characteristic,
          error: MockBleError.characteristicNotFound)
        return
      }
      @Sendable func _readInternal() {
        mutex.lock()
        defer { mutex.unlock() }
        peripheralDelegate?.blePeripheral(
          self,
          didUpdateValueFor: internalCharacteristic,
          error: nil)
      }
      _readInternal()
    }
  }

  /// to simulate ble device side characteristic updating (and notifying) state that is not 1-to-1 with a command/write/read
  func updateValueInternal(_ data: Data, for characteristic: CBCharacteristic) {
    guard let internalCharacteristic = findInternalMutableCharacteristic(characteristic) else {
      peripheralDelegate?.blePeripheral(
        self,
        didUpdateValueFor: characteristic,
        error: MockBleError.characteristicNotFound)
      return
    }
    @Sendable func _writeInternal() {
      mutex.lock()
      defer { mutex.unlock() }
      internalCharacteristic.value = data
      peripheralDelegate?.blePeripheral(
        self,
        didWriteValueFor: internalCharacteristic,
        error: nil)
    }
    _writeInternal()
  }

  func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {
    queue.async { [weak self] in
      guard let self else { return }

      mutex.lock()
      defer { mutex.unlock() }

      guard state == .connected else {
        peripheralDelegate?.blePeripheral(
          self,
          didUpdateValueFor: characteristic,
          error: MockBleError.peripheralNotConnected)
        return
      }
      if type == .withResponse {
        guard characteristic.properties.contains(.write) else {
          peripheralDelegate?.blePeripheral(
            self,
            didUpdateValueFor: characteristic,
            error: MockBleError.operationNotSupported)
          return
        }
      } else {
        guard characteristic.properties.contains(.writeWithoutResponse) else {
          peripheralDelegate?.blePeripheral(
            self,
            didUpdateValueFor: characteristic,
            error: MockBleError.operationNotSupported)
          return
        }
      }

      updateValueInternal(data, for: characteristic)
    }
  }

  func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
    queue.async { [weak self] in
      guard let self else { return }
      mutex.lock()
      defer { mutex.unlock() }
      guard state == .connected else {
        peripheralDelegate?.blePeripheral(
          self,
          didUpdateValueFor: characteristic,
          error: MockBleError.peripheralNotConnected)
        return
      }
      guard characteristic.properties.contains(.notify) else {
        peripheralDelegate?.blePeripheral(
          self,
          didUpdateValueFor: characteristic,
          error: MockBleError.operationNotSupported)
        return
      }
      guard let internalCharacteristic = findInternalMutableCharacteristic(characteristic) else {
        peripheralDelegate?.blePeripheral(
          self,
          didUpdateValueFor: characteristic,
          error: MockBleError.characteristicNotFound)
        return
      }
      @Sendable func _notifyInternal() {
        mutex.lock()
        defer { mutex.unlock() }
        internalCharacteristic.internalIsNotifying = enabled
        peripheralDelegate?.blePeripheral(
          self,
          didUpdateNotificationStateFor: internalCharacteristic,
          error: nil)
      }
      _notifyInternal()
    }
  }

  func readRSSI() {

    queue.async { [weak self] in

      guard let self else { return }

      mutex.lock()
      defer { mutex.unlock() }

      guard state == .connected else {
        peripheralDelegate?.blePeripheral(
          self,
          didReadRSSI: NSNumber(value: -1),
          error: MockBleError.peripheralNotConnected)
        return
      }
      @Sendable func _readInternal() {
        mutex.lock()
        defer { mutex.unlock() }
        peripheralDelegate?.blePeripheral(
          self,
          didReadRSSI: NSNumber(value: rssi),
          error: nil)
      }

      _readInternal()
    }

  }

  func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
    return 180
  }

  // MARK: - Internal characteristics discovery
  private func discoverPositionServiceCharacteristics(_ characteristicUUIDs: [CBUUID]?) {
    mutex.lock()
    defer { mutex.unlock() }

    guard state == .connected else {
      peripheralDelegate?.blePeripheral(
        self,
        didDiscoverCharacteristicsFor: positionService,
        error: MockBleError.peripheralNotConnected)
      return
    }

    addCharacteristicIfNeeded(
      MockCBCharacteristic(
        type: LinakBLEControllerDescriptor.PositionService.HeightAndSpeedCharacteristic.uuid,
        properties: [.read, .notify],
        value: position.data(),
        permissions: .readable),
      to: positionService,
      characteristicUUIDs: characteristicUUIDs)

    peripheralDelegate?.blePeripheral(
      self,
      didDiscoverCharacteristicsFor: positionService,
      error: nil)
  }

  private func discoverMoveServiceCharacteristics(_ characteristicUUIDs: [CBUUID]?) {
    mutex.lock()
    defer { mutex.unlock() }

    guard state == .connected else {
      peripheralDelegate?.blePeripheral(
        self,
        didDiscoverCharacteristicsFor: moveService,
        error: MockBleError.peripheralNotConnected)
      return
    }

    addCharacteristicIfNeeded(
      MockCBCharacteristic(
        type: LinakBLEControllerDescriptor.MoveService.MoveCharacteristic.uuid,
        properties: [.write],
        value: nil,
        permissions: .writeable),
      to: moveService,
      characteristicUUIDs: characteristicUUIDs)

    peripheralDelegate?.blePeripheral(
      self,
      didDiscoverCharacteristicsFor: moveService,
      error: nil)
  }

  // MARK: - Internals
  private func addCharacteristicIfNeeded(_ characteristic: MockCBCharacteristic, to service: CBMutableService, characteristicUUIDs: [CBUUID]?) {
    service.characteristics = service.characteristics.emptyIfNil
    guard characteristicUUIDs == nil || characteristicUUIDs!.contains(characteristic.uuid) else { return }
    guard findInternalMutableCharacteristic(characteristic) == nil else { return }
    service.characteristics?.append(characteristic)
  }

  private func findInternalMutableCharacteristic(_ characteristic: CBCharacteristic) -> MockCBCharacteristic? {
    return findInternalMutableCharacteristic(characteristic.uuid)
  }

  private func findInternalMutableCharacteristic(_ characteristicUUID: CBUUID) -> MockCBCharacteristic? {
    let service = services?.first {
      $0.characteristics?.contains { characteristic in
        characteristic.uuid == characteristicUUID
      } ?? false
    }
    return service?.characteristics?.first {
      $0.uuid == characteristicUUID
    } as? MockCBCharacteristic
  }

  // MARK: - Internal notify
  private func startNotify() {
    mutex.lock()
    defer { mutex.unlock() }
    timer?.cancel()
    timer = DispatchSource.makeTimerSource(queue: .global())
    timer?.schedule(deadline: .now() + .seconds(1), repeating: 1.0)
    timer?.setEventHandler { [weak self] in
      guard let self else { return }
      notifyInterval()
    }
    timer?.resume()
  }

  private func stopNotify() {
    mutex.lock()
    defer { mutex.unlock() }
    timer?.cancel()
    timer = nil
  }

  private func notifyInterval() {
    mutex.lock()
    defer { mutex.unlock() }
    for service in services ?? [] {
      for characteristic in service.characteristics ?? [] {
        if characteristic.isNotifying, characteristic.value != nil {
          peripheralDelegate?.blePeripheral(
            self,
            didUpdateValueFor: characteristic,
            error: nil)
        }
      }
    }
  }

  // MARK: - Utils
  func readRSSI(after timeout: DispatchTimeInterval) {
    queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
      guard let self else { return }
      mutex.lock()
      defer { mutex.unlock() }
      self.readRSSI()
    }
  }

  func setName(_ name: String?, after timeout: DispatchTimeInterval) {
    queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
      guard let self else { return }
      mutex.lock()
      defer { mutex.unlock() }
      self.name = name
    }
  }
}

class MockCBCharacteristic: CBMutableCharacteristic, @unchecked Sendable {
  @Atomic
  var internalIsNotifying: Bool = false

  override var isNotifying: Bool { internalIsNotifying }
}
