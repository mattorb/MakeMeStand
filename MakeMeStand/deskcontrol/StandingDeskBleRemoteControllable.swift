import BlueConnect
import Combine
import CoreBluetooth
import Foundation

protocol StandingDeskBleRemoteControllable {
  func scanForNearbyDesks(autoConnectFirstFound: Bool) async throws
  func connect(_ desk: BlePeripheral) async throws
  func disconnect(_ desk: BlePeripheral) async throws

  func moveUp() async throws
  func moveDown() async throws
  func moveStop() async throws
  func move(to desiredHeight: Measurement<UnitLength>) async throws

  /// height includes minimum (physical) desk height + offset as measured from BT characteristic
  func currentHeight() async throws -> Measurement<UnitLength>

  var activeDeskState: BleDeskConnectionState { get }
  var nearbyDesks: [UUID: BlePeripheral] { get }
}

enum BleDeskConnectionState {
  case unknown
  case disconnecting
  case disconnected
  case connecting
  case connected(BlePeripheral, BlePeripheralProxy, DeskPositionProxy?, DeskMoveCommandProxy?, Measurement<UnitLength>)
}

extension BleDeskConnectionState {
  var height: Measurement<UnitLength>? {
    if case .connected(_, _, _, _, let currentHeight) = self {
      return currentHeight
    } else {
      return nil
    }
  }
}
