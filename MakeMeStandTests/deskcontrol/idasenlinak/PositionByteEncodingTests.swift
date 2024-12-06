import Foundation
import Testing

@testable import MakeMeStand

struct PositionByteEncodingTests {
  @Test func encodeDecode() async throws {
    let deskPosition = DeskPosition(rawPosition: 12345, rawSpeed: 300)
    let data = deskPosition.data()
    #expect(data.count == 4)  // 2 bytes, 2 bytes

    let decodedPosition = DeskPosition(from: data)

    #expect(decodedPosition.rawPosition == 12345)
    #expect(decodedPosition.rawSpeed == 300)
  }
  @Test func encodeDecodeTypeLimits() async throws {
    let deskPosition = DeskPosition(rawPosition: UInt16.max, rawSpeed: Int16.min)
    let data = deskPosition.data()
    #expect(data.count == 4)  // 2 bytes, 2 bytes

    let decodedPosition = DeskPosition(from: data)

    #expect(decodedPosition.rawPosition == UInt16.max)
    #expect(decodedPosition.rawSpeed == Int16.min)
  }
}

/// Helper for Mocks (live use only decodes, never encodes, since moving is handled from seperate BLE service+characteristic)
extension DeskPosition {
  func data() -> Data {
    var data = Data()

    withUnsafeBytes(of: rawPosition.littleEndian) { buffer in
      data.append(contentsOf: buffer)
    }

    withUnsafeBytes(of: rawSpeed.littleEndian) { buffer in
      data.append(contentsOf: buffer)
    }

    return data
  }
}
