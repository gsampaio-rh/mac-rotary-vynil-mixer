import SwiftUI

@main
struct VinylAudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = VinylSettings()
    @StateObject private var engine = AudioEngineManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(settings: settings, engine: engine)
        } label: {
            Image(systemName: engine.isRunning ? "opticaldisc.fill" : "opticaldisc")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DeviceManager.restorePersistedDevices()
    }
}
