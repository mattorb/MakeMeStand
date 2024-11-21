import Foundation
import SimpleLogger

public struct Log {
  private static let subsystemId: String =
    Bundle.main.bundleIdentifier
    ?? {
      fatalError("Bundle Identifier not found.")
    }()

  #if DEBUG
    public static let app: LoggerManagerProtocol = .default(subsystem: subsystemId, category: "app")
  #else
    struct NoOpLogger: LoggerManagerProtocol {
      func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {}
    }
    public static let app: LoggerManagerProtocol = NoOpLogger()
  #endif
}
