import Combine
import Foundation

/// Detect physical desk switch up/down double tap
class IdasenLinakBleDoubleTapSwitchDetector {
  let deskPositionProxy: DeskPositionProxy
  let doubleTapThresholdSeconds: Double

  var onDoubleTapPublisher: PassthroughSubject<SwitchMoveDirection, Never> = PassthroughSubject()

  var subscriptions: Set<AnyCancellable> = []

  init(deskPositionProxy: DeskPositionProxy, doubleTapThresholdSeconds: Double) {
    self.deskPositionProxy = deskPositionProxy
    self.doubleTapThresholdSeconds = doubleTapThresholdSeconds

    deskPositionProxy.didUpdateValuePublisher
      .receive(on: DispatchQueue.main)
      .collect(.byTime(DispatchQueue.main, .init(floatLiteral: doubleTapThresholdSeconds)))
      .filter { positions in
        let twoDiscreteStops =
          positions.filter {
            $0.rawSpeed == 0
          }.count == 2

        let moves = positions.filter { $0.rawSpeed != 0 }
        let allMovesUp = moves.allSatisfy { $0.rawSpeed > 0 }
        let allMovesDown = moves.allSatisfy { $0.rawSpeed < 0 }

        return twoDiscreteStops && (allMovesUp || allMovesDown)
      }
      .map { positions in
        let moves = positions.filter { $0.rawSpeed != 0 }
        let allMovesUp = moves.allSatisfy { $0.rawSpeed > 0 }

        if allMovesUp {
          return SwitchMoveDirection.up
        } else {
          return SwitchMoveDirection.down
        }
      }
      .sink(receiveValue: { switchDirection in
        self.onDoubleTapPublisher.send(switchDirection)
      })
      .store(in: &subscriptions)
  }
}
