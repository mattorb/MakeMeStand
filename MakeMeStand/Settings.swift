import Foundation
import SwiftUI

@Observable
class Settings {
  let userDefaultsProvider: UserDefaultsProvider

  init(userDefaultsProvider: UserDefaultsProvider = SystemUserDefaultsProvider()) {
    self.userDefaultsProvider = userDefaultsProvider
  }

  var autoConnect: Setting<Bool> { .init("autoConnect", defaultValue: true, userDefaultsProvider: userDefaultsProvider) }
  var autoStand: Setting<Bool> { .init("autoStand", defaultValue: true, userDefaultsProvider: userDefaultsProvider) }
  var showHeightInMenuBar: Setting<Bool> { .init("showHeightInMenuBar", defaultValue: true, userDefaultsProvider: userDefaultsProvider) }
  var autoStandMinute: Setting<Int> { .init("autoStandMinute", defaultValue: 55, userDefaultsProvider: userDefaultsProvider) }
  var autoSitMinute: Setting<Int> { .init("autoSitMinute", defaultValue: 00, userDefaultsProvider: userDefaultsProvider) }
  var autoStandInactivityTimeout: Setting<Int> { .init("autoStandInactivityTimeout", defaultValue: 5, userDefaultsProvider: userDefaultsProvider) }
  var standingHeightIn: Setting<Double> { .init("standingHeightIn", defaultValue: 40.2244, userDefaultsProvider: userDefaultsProvider) }
  var sittingHeightIn: Setting<Double> { .init("sittingHeightIn", defaultValue: 25.00, userDefaultsProvider: userDefaultsProvider) }
  var doubleTapSwitch: Setting<Bool> { .init("doubleTapSwitch", defaultValue: false, userDefaultsProvider: userDefaultsProvider) }
  var pinToLastConnectedDesk: Setting<Bool> { .init("pinToLastConnectedDesk", defaultValue: false, userDefaultsProvider: userDefaultsProvider) }
  var lastConnectedDeskUUID: Setting<String?> { .init("lastConnectedDeskUUID", defaultValue: nil, userDefaultsProvider: userDefaultsProvider) }
}

protocol UserDefaultsProvider {
  var userDefaults: UserDefaults { get }
}

struct SystemUserDefaultsProvider: UserDefaultsProvider {
  var userDefaults: UserDefaults {
    return .standard
  }
}

struct Setting<Value> {
  let userDefaultsProvider: UserDefaultsProvider
  let key: String
  let defaultValue: Value

  init(_ key: String, defaultValue: Value, userDefaultsProvider: UserDefaultsProvider = SystemUserDefaultsProvider()) {
    self.key = key
    self.defaultValue = defaultValue
    self.userDefaultsProvider = userDefaultsProvider
  }

  func currentValue() -> Value {
    let userDefaults = userDefaultsProvider.userDefaults
    if let value = userDefaults.object(forKey: key) as? Value {
      return value
    }

    return defaultValue
  }
}

extension Setting where Value == String? {
  func save(_ value: String?) {
    userDefaultsProvider.userDefaults.set(value, forKey: key)
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
