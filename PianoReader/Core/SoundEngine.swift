import AVFoundation

/// Sonido de las pistas, del teclado en pantalla y del clic del metrónomo.
/// Usa el sonido por defecto de AVAudioUnitSampler (se puede cambiar por un .sf2 de piano).
final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let piano = AVAudioUnitSampler()
    private let clicker = AVAudioUnitSampler()

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        engine.attach(piano)
        engine.attach(clicker)
        engine.connect(piano, to: engine.mainMixerNode, format: nil)
        engine.connect(clicker, to: engine.mainMixerNode, format: nil)
        try? engine.start()
        clicker.volume = Float(UserDefaults.standard.object(forKey: Self.clickVolumeKey) as? Double ?? 1)
        // Piano real: Upright Piano KW de FreePats (CC0), en Resources/Piano.sf2.
        if let url = Bundle.main.url(forResource: "Piano", withExtension: "sf2") {
            try? piano.loadSoundBankInstrument(at: url, program: 0, bankMSB: 0x79, bankLSB: 0)
        }
    }

    func play(_ notes: [Int], duration: TimeInterval = 1.0) {
        ensureRunning()
        for note in notes { piano.startNote(UInt8(note), withVelocity: 100, onChannel: 0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [piano] in
            for note in notes { piano.stopNote(UInt8(note), onChannel: 0) }
        }
    }

    /// Nota que suena mientras se mantiene pulsada (botón de ritmo): empieza al tocar y se apaga al soltar.
    func noteOn(_ note: Int) {
        ensureRunning()
        piano.startNote(UInt8(note), withVelocity: 100, onChannel: 0)
    }

    func noteOff(_ note: Int) {
        piano.stopNote(UInt8(note), onChannel: 0)
    }

    /// Reproduce acordes/notas uno tras otro, separados por `gap` segundos.
    func play(sequence: [[Int]], gap: TimeInterval) {
        for (i, chord) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + gap * Double(i)) { [weak self] in
                self?.play(chord, duration: gap * 0.9)
            }
        }
    }

    /// Cada reproducción con ritmo nueva (o `stopAll`) cancela lo que quedaba pendiente de la anterior.
    private var generation = 0

    /// Reproduce notas con ritmo, empezando dentro de `delay` segundos. Reemplaza a la anterior.
    func play(timed notes: [(start: TimeInterval, midi: Int, duration: TimeInterval)], after delay: TimeInterval) {
        stopAll()
        let current = generation
        for note in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + note.start) { [weak self] in
                guard let self, self.generation == current else { return }
                self.play([note.midi], duration: note.duration)
            }
        }
    }

    /// Corta la reproducción con ritmo y las notas que suenan.
    func stopAll() {
        generation += 1
        for note in 21...108 { piano.stopNote(UInt8(note), onChannel: 0) }
    }

    static let clickVolumeKey = "clickVolume"

    /// Volumen del clic del metrónomo (0…1); se guarda y se aplica al momento.
    var clickVolume: Double {
        get { Double(clicker.volume) }
        set {
            clicker.volume = Float(min(max(newValue, 0), 1))
            UserDefaults.standard.set(newValue, forKey: Self.clickVolumeKey)
        }
    }

    func click(accent: Bool) {

        ensureRunning()
        let note: UInt8 = accent ? 96 : 84
        clicker.startNote(note, withVelocity: accent ? 127 : 80, onChannel: 0)
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.05) { [clicker] in
            clicker.stopNote(note, onChannel: 0)
        }
    }

    private func ensureRunning() {
        if !engine.isRunning { try? engine.start() }
    }
}
