enum MockBleError: Error {
  case bluetoothIsOff
  case characteristicNotFound
  case characteristicNotRead
  case decodingError
  case encodingError
  case mockedError
  case operationNotSupported
  case peripheralNotConnected
}
