import Foundation
import Observation

enum ClefChoice: String, CaseIterable, Identifiable, Codable {
    case treble, bass, both
    var id: String { rawValue }

    var label: String {
        switch self {
        case .treble: "Sol"
        case .bass: "Fa"
        case .both: "Ambas"
        }
    }

    func pick() -> Clef {
        switch self {
        case .treble: .treble
        case .bass: .bass
        case .both: Bool.random() ? .treble : .bass
        }
    }
}

enum ExerciseKind: String, CaseIterable, Identifiable, Codable {
    case single, interval, triad, progression
    var id: String { rawValue }

    var label: String {
        switch self {
        case .single: "Nota"
        case .interval: "Dos notas"
        case .triad: "Tríada"
        case .progression: "Progresión"
        }
    }
}

enum DisplayMode: String, CaseIterable, Identifiable, Codable {
    case staff, name, both
    var id: String { rawValue }

    var label: String {
        switch self {
        case .staff: "Partitura"
        case .name: "Nombre"
        case .both: "Ambos"
        }
    }
}

/// Compás. En 6/8 el clic va por corcheas con acentos en 1 y 4.
enum Meter: String, CaseIterable, Identifiable, Codable {
    case twoFour = "2/4", threeFour = "3/4", fourFour = "4/4", sixEight = "6/8"
    var id: String { rawValue }

    var beats: Int {
        switch self {
        case .twoFour: 2
        case .threeFour: 3
        case .fourFour: 4
        case .sixEight: 6
        }
    }

    var accents: Set<Int> { self == .sixEight ? [0, 3] : [0] }
}

/// Tiempo disponible por nota (o acorde) con metrónomo.
enum BeatWindow: String, CaseIterable, Identifiable, Codable {
    case oneBeat, twoBeats, measure, twoMeasures
    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneBeat: "1 tiempo"
        case .twoBeats: "2 tiempos"
        case .measure: "1 compás"
        case .twoMeasures: "2 compases"
        }
    }

    func beats(_ meter: Meter) -> Int {
        switch self {
        case .oneBeat: 1
        case .twoBeats: 2
        case .measure: meter.beats
        case .twoMeasures: meter.beats * 2
        }
    }

    /// Menos tiempo = más puntos.
    var speedFactor: Double {
        switch self {
        case .oneBeat: 1.5
        case .twoBeats: 1.25
        case .measure: 1.0
        case .twoMeasures: 0.8
        }
    }
}

struct PracticeSettings: Codable, Equatable {
    var clef: ClefChoice = .treble
    var kinds: Set<ExerciseKind> = [.single]
    var progressionLength = 4
    var ledgerLines = false
    var accidentals = false
    var exactOctave = false
    var display: DisplayMode = .staff
    var naming: NamingStyle = .english
    /// 0 = sin límite.
    var sessionLength = 20

    var metronome = false
    var bpm = 80
    var meter: Meter = .fourFour
    var window: BeatWindow = .measure
    var metronomeClick = true

    init() {}

    /// Campos que falten (ajustes guardados por una versión anterior) toman su valor por defecto.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PracticeSettings()
        clef = try c.decodeIfPresent(ClefChoice.self, forKey: .clef) ?? d.clef
        kinds = try c.decodeIfPresent(Set<ExerciseKind>.self, forKey: .kinds) ?? d.kinds
        progressionLength = try c.decodeIfPresent(Int.self, forKey: .progressionLength) ?? d.progressionLength
        ledgerLines = try c.decodeIfPresent(Bool.self, forKey: .ledgerLines) ?? d.ledgerLines
        accidentals = try c.decodeIfPresent(Bool.self, forKey: .accidentals) ?? d.accidentals
        exactOctave = try c.decodeIfPresent(Bool.self, forKey: .exactOctave) ?? d.exactOctave
        display = try c.decodeIfPresent(DisplayMode.self, forKey: .display) ?? d.display
        naming = try c.decodeIfPresent(NamingStyle.self, forKey: .naming) ?? d.naming
        sessionLength = try c.decodeIfPresent(Int.self, forKey: .sessionLength) ?? d.sessionLength
        metronome = try c.decodeIfPresent(Bool.self, forKey: .metronome) ?? d.metronome
        bpm = try c.decodeIfPresent(Int.self, forKey: .bpm) ?? d.bpm
        meter = try c.decodeIfPresent(Meter.self, forKey: .meter) ?? d.meter
        window = try c.decodeIfPresent(BeatWindow.self, forKey: .window) ?? d.window
        metronomeClick = try c.decodeIfPresent(Bool.self, forKey: .metronomeClick) ?? d.metronomeClick
    }

    var metronomeSummary: String {
        metronome ? "\(bpm) BPM · \(meter.rawValue) · \(window.label)" : "Apagado"
    }
}

@Observable
final class SettingsStore {
    private static let key = "practiceSettings"

    var settings: PracticeSettings {
        didSet {
            if let data = try? JSONEncoder().encode(settings) {
                UserDefaults.standard.set(data, forKey: Self.key)
            }
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(PracticeSettings.self, from: data) {
            settings = saved
        } else {
            settings = PracticeSettings()
        }
    }
}
