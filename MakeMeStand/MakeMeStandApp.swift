import SwiftUI

@main
struct MakeMeStandApp: App {
  let container = DependencyContainer()  // trying this out vs @State with _var=.init(initialValue) approach

  init() {
    initializeDependencies(container: container)
  }

  var body: some Scene {
    MakeMeStandMenuBar()
      .environment(Settings.self, from: container)
      .environment(IdasenLinakBleRemoteControl.self, from: container)
      .environment(PeriodicAutoStand.self, from: container)
  }
}
