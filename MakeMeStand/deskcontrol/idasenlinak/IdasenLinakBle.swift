import BlueConnect
import Combine
import CoreBluetooth
import Foundation

// - MARK: BLE service/characteristic hierarchy

public enum LinakBLEControllerDescriptor {}
extension LinakBLEControllerDescriptor {
  public enum PositionService {
    public static let uuid = CBUUID(string: "99FA0020-338A-1024-8A49-009C0215F78A")
    public enum HeightAndSpeedCharacteristic {
      public static let uuid = CBUUID(string: "99FA0021-338A-1024-8A49-009C0215F78A")
    }
  }
}

extension LinakBLEControllerDescriptor {
  public enum MoveService {
    public static let uuid = CBUUID(string: "99FA0001-338A-1024-8A49-009C0215F78A")
    public enum MoveCharacteristic {
      public static let uuid = CBUUID(string: "99FA0002-338A-1024-8A49-009C0215F78A")

      public enum CommandHex: String {
        case up = "4700"
        case down = "4600"
        case stop = "FF00"
      }
    }
  }
}

// - MARK: position service domain + encoding

public struct DeskPosition {
  public static let lowestPhysicalHeight: Measurement<UnitLength> = Measurement(value: 61.5, unit: .centimeters)

  public let rawPosition: UInt16  // offset in tenth's of millimeters
  public let rawSpeed: Int16  // unknown unit of measure, positive/negative indicates direction though

  var height: Measurement<UnitLength> {
    let raisedOffsetHeight = Measurement(value: Double(rawPosition), unit: UnitLength.tenthsOfMillimeters)
    let actualHeight = DeskPosition.lowestPhysicalHeight + raisedOffsetHeight

    return actualHeight.converted(to: .centimeters)
  }
}

extension DeskPosition {
  public init(from data: Data) {
    // position = 16, little endian, unsigned
    // speed = 16, little endian, signed

    rawPosition = [data[0], data[1]].withUnsafeBytes {
      $0.load(as: UInt16.self)
    }

    rawSpeed = [data[2], data[3]].withUnsafeBytes {
      $0.load(as: Int16.self)
    }
  }
}

struct DeskPositionProxy: BleCharacteristicReadProxy, BleCharacteristicNotifyProxy {
  typealias ValueType = DeskPosition

  var characteristicUUID: CBUUID = LinakBLEControllerDescriptor.PositionService.HeightAndSpeedCharacteristic.uuid
  var serviceUUID: CBUUID = LinakBLEControllerDescriptor.PositionService.uuid

  weak var peripheralProxy: BlePeripheralProxy?

  init(peripheralProxy: BlePeripheralProxy) {
    self.peripheralProxy = peripheralProxy
  }

  func decode(_ data: Data) throws -> DeskPosition {
    return DeskPosition(from: data)
  }
}

// - MARK: move service domain + encoding

enum DeskMoveCommand {
  case up
  case down
  case stop
}

extension DeskMoveCommand {
  var data: Data {
    let hexCommandString: String

    switch self {
    case .down: hexCommandString = LinakBLEControllerDescriptor.MoveService.MoveCharacteristic.CommandHex.down.rawValue
    case .up: hexCommandString = LinakBLEControllerDescriptor.MoveService.MoveCharacteristic.CommandHex.up.rawValue
    case .stop: hexCommandString = LinakBLEControllerDescriptor.MoveService.MoveCharacteristic.CommandHex.stop.rawValue
    }

    return Data(hexString: hexCommandString) ?? Data()
  }
}

struct DeskMoveCommandProxy: BleCharacteristicWriteProxy {
  typealias ValueType = DeskMoveCommand

  var characteristicUUID: CBUUID = LinakBLEControllerDescriptor.MoveService.MoveCharacteristic.uuid
  var serviceUUID: CBUUID = LinakBLEControllerDescriptor.MoveService.uuid

  weak var peripheralProxy: BlePeripheralProxy?

  init(peripheralProxy: BlePeripheralProxy) {
    self.peripheralProxy = peripheralProxy
  }

  func encode(_ value: DeskMoveCommand) throws -> Data {
    return value.data
  }
}

/// The physical switch on the desk
enum SwitchMoveDirection {
  case up
  case down
}

/// raw height value from BT characteristic is in this UOM
extension UnitLength {
  static let tenthsOfMillimeters = UnitLength(symbol: "0.1 mm", converter: UnitConverterLinear(coefficient: 0.0001))
}
