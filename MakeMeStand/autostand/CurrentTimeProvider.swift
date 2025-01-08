import Foundation

protocol CurrentTimeProvider {
  func now() -> Date
}

struct SystemTimeProvider: CurrentTimeProvider {
  func now() -> Date {
    return Date()
  }
}
