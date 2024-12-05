import Combine
import Foundation

/// Detect physical desk switch up/down double tap
class IdasenLinakBleDoubleTapSwitchDetector {
  let deskPositionProxy: DeskPositionProxy

  var onDoubleTapPublisher: PassthroughSubject<SwitchMoveDirection, Never> = PassthroughSubject()

  var subscriptions: Set<AnyCancellable> = []

  init(deskPositionProxy: DeskPositionProxy) {
    self.deskPositionProxy = deskPositionProxy

    deskPositionProxy.didUpdateValuePublisher
      .receive(on: DispatchQueue.main)
      .collect(.byTime(DispatchQueue.main, 1.0))
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
