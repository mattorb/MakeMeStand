import Foundation
import SwiftUI

@Observable
class Settings {
  var autoConnect: Setting<Bool> { .init("autoConnect", defaultValue: true) }
  var autoStand: Setting<Bool> { .init("autoStand", defaultValue: true) }
  var showHeightInMenuBar: Setting<Bool> { .init("showHeightInMenuBar", defaultValue: true) }
  var autoStandMinute: Setting<Int> { .init("autoStandMinute", defaultValue: 55) }
  var autoSitMinute: Setting<Int> { .init("autoSitMinute", defaultValue: 60) }
  var autoStandInactivityTimeout: Setting<Int> { .init("autoStandInactivityTimeout", defaultValue: 5) }
  var standingHeightIn: Setting<Double> { .init("standingHeightIn", defaultValue: 40.2244) }
  var sittingHeightIn: Setting<Double> { .init("sittingHeightIn", defaultValue: 25.00) }
  var doubleTapSwitch: Setting<Bool> { .init("doubleTapSwitch", defaultValue: false) }
}

struct Setting<Value> {
  let key: String
  let defaultValue: Value

  init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
  }

  func currentValue() -> Value {
    let userDefaults: UserDefaults = .standard

    if let value = userDefaults.object(forKey: key) as? Value {
      return value
    }

    return defaultValue
  }
}

// - MARK: @AppStorage strongly typed access.  i.e. - @AppStorage(\.settingName)

extension AppStorage where Value == Bool {
  init(wrappedValue: Bool, strongKey: Setting<Value>, store: UserDefaults? = nil) {
    self.init(wrappedValue: wrappedValue, strongKey.key, store: store)
  }

  init(_ strongKeyPath: KeyPath<Settings, Setting<Value>>, store: UserDefaults? = nil) {
    let strongKey = Settings()[keyPath: strongKeyPath]
    self.init(wrappedValue: strongKey.defaultValue, strongKey: strongKey, store: store)
  }
}

extension AppStorage where Value == Int {
  init(wrappedValue: Int, strongKey: Setting<Value>, store: UserDefaults? = nil) {
    self.init(wrappedValue: wrappedValue, strongKey.key, store: store)
  }

  init(_ strongKeyPath: KeyPath<Settings, Setting<Value>>, store: UserDefaults? = nil) {
    let strongKey = Settings()[keyPath: strongKeyPath]
    self.init(wrappedValue: strongKey.defaultValue, strongKey: strongKey, store: store)
  }
}

extension AppStorage where Value == Double {
  init(wrappedValue: Double, strongKey: Setting<Value>, store: UserDefaults? = nil) {
    self.init(wrappedValue: wrappedValue, strongKey.key, store: store)
  }

  init(_ strongKeyPath: KeyPath<Settings, Setting<Value>>, store: UserDefaults? = nil) {
    let strongKey = Settings()[keyPath: strongKeyPath]
    self.init(wrappedValue: strongKey.defaultValue, strongKey: strongKey, store: store)
  }
}
