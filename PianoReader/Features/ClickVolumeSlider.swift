import SwiftUI

/// Volumen del clic del metrónomo: se oye el cambio al momento.
struct ClickVolumeSlider: View {
    @AppStorage(SoundEngine.clickVolumeKey) private var volume = 1.0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill").foregroundStyle(.secondary)
            Slider(value: $volume, in: 0...1)
                .accessibilityLabel("Volumen del metrónomo")
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
        }
        .onChange(of: volume) { _, value in SoundEngine.shared.clickVolume = value }
    }
}
