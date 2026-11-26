import SwiftUI

@main
struct PianoReaderApp: App {
    @State private var midi = MIDIManager()
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(midi)
                .environment(settings)
        }
    }
}
