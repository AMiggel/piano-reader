import SwiftUI

@main
struct PianoReaderApp: App {
    @State private var midi = MIDIManager()
    @State private var settings = SettingsStore()
    @State private var progress = ProgressStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(progress)
                .environment(midi)
                .environment(settings)
        }
    }
}
