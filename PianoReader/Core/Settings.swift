import Foundation
import Observation

/// Mano que se practica: derecha = clave de sol, izquierda = clave de fa, ambas = pentagrama doble.
enum ClefChoice: String, CaseIterable, Identifiable, Codable {
    case treble, bass, both
    var id: String { rawValue }

    var label: String {
        switch self {
        case .treble: "Derecha"
        case .bass: "Izquierda"
        case .both: "Ambas"
        }
    }

    var detail: String {
        switch self {
        case .treble: "Mano derecha · clave de sol"
        case .bass: "Mano izquierda · clave de fa"
        case .both: "Ambas manos · sol y fa"
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

    /// Lo que se puede elegir: cada nota del compás puede salir suelta, como intervalo o como tríada.
    /// (`progression` queda solo para leer ajustes antiguos: el compás ya es una progresión.)
    static let selectable: [ExerciseKind] = [.single, .interval, .triad]
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

/// Compás. En los de corchea (3/8, 6/8, 9/8, 12/8) el clic va por corcheas con acento cada tres;
/// en 2/2 (alla breve) por blancas; en el resto por negras.
enum Meter: String, CaseIterable, Identifiable, Codable {
    case twoFour = "2/4", threeFour = "3/4", fourFour = "4/4", fiveFour = "5/4", twoTwo = "2/2"
    case threeEight = "3/8", sixEight = "6/8", nineEight = "9/8", twelveEight = "12/8"
    var id: String { rawValue }

    /// Clics por compás.
    var beats: Int { Int(numerator) ?? 4 }

    /// Compás de corcheas: se agrupa en tiempos de negra con puntillo.
    var isCompound: Bool { denominator == "8" }

    var accents: Set<Int> {
        if isCompound { return Set(stride(from: 0, to: beats, by: 3)) }
        return self == .fiveFour ? [0, 3] : [0]
    }

    /// Ticks por clic: negra = 48, corchea = 24, blanca = 96.
    var ticksPerClick: Int {
        switch denominator {
        case "8": 24
        case "2": 96
        default: 48
        }
    }
    var measureTicks: Int { beats * ticksPerClick }
    /// Tiempo para agrupar corcheas y acordes: negra con puntillo en los de corchea, negra en el resto.
    var beatTicks: Int { isCompound ? 72 : 48 }
    /// Acordes por compás en el acompañamiento: dos en los compases largos y pares.
    var harmonySlots: Int { [.fourFour, .twoTwo, .sixEight, .twelveEight].contains(self) ? 2 : 1 }

    var numerator: String { String(rawValue.split(separator: "/")[0]) }
    var denominator: String { String(rawValue.split(separator: "/")[1]) }
    /// Figura del clic para escribir "♩ = 120".
    var clickSymbol: String {
        switch denominator {
        case "8": "♪"
        case "2": "𝅗𝅥"
        default: "♩"
        }
    }
}

/// Términos italianos de tempo con su rango de BPM (sin solaparse) y lo que significan.
enum TempoMark: String, CaseIterable, Identifiable, Codable {
    case grave, largo, adagio, andante, moderato, allegretto, allegro, vivace, presto, prestissimo
    var id: String { rawValue }

    var name: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    var range: ClosedRange<Int> {
        switch self {
        case .grave: 20...44
        case .largo: 45...59
        case .adagio: 60...75
        case .andante: 76...99
        case .moderato: 100...111
        case .allegretto: 112...119
        case .allegro: 120...155
        case .vivace: 156...175
        case .presto: 176...199
        case .prestissimo: 200...240
        }
    }

    /// Tempo típico de cada término.
    var bpm: Int {
        switch self {
        case .grave: 40
        case .largo: 50
        case .adagio: 70
        case .andante: 88
        case .moderato: 108
        case .allegretto: 116
        case .allegro: 132
        case .vivace: 164
        case .presto: 184
        case .prestissimo: 208
        }
    }

    var meaning: String {
        switch self {
        case .grave: "Muy lento y solemne"
        case .largo: "Lento y amplio"
        case .adagio: "Lento, con calma"
        case .andante: "Al paso, tranquilo"
        case .moderato: "Moderado"
        case .allegretto: "Algo rápido"
        case .allegro: "Rápido y alegre"
        case .vivace: "Vivo, animado"
        case .presto: "Muy rápido"
        case .prestissimo: "Lo más rápido posible"
        }
    }

    static func mark(for bpm: Int) -> TempoMark {
        allCases.first { $0.range.contains(bpm) } ?? (bpm < 20 ? .grave : .prestissimo)
    }
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
    /// Compases que pueden salir; con más de uno se elige uno al azar por sesión.
    var meters: Set<Meter> = [.fourFour]
    /// Último nivel aplicado (0 = ninguno).
    var level = 0
    var window: BeatWindow = .measure
    var metronomeClick = true

    var rhythmFeatures: Set<RhythmFeature> = [.long, .eighths]
    var rhythmMeasures = 1
    var repeatOnFail = true
    /// Tonalidades elegidas (armaduras, −7…7); se escoge una al azar por ejercicio.
    var keyFifths: Set<Int> = [0]
    /// Cuánto se mueve la mano en la melodía (5 dedos, octava o libre).
    var motion: HandMotion = .fixed
    /// Con las dos manos, la izquierda en clave de sol (como Czerny hasta el No. 31).
    var leftHandTreble = false
    /// Solo ritmo: una línea, cualquier tecla vale; se evalúa cuándo empieza y cuánto dura cada figura.
    var rhythmOnly = false
    /// Términos de tempo que pueden salir; con alguno elegido, cada sesión trae su tempo (y su término).
    var tempoMarks: Set<TempoMark> = []

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
        meters = try c.decodeIfPresent(Set<Meter>.self, forKey: .meters) ?? [meter]
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? d.level
        window = try c.decodeIfPresent(BeatWindow.self, forKey: .window) ?? d.window
        metronomeClick = try c.decodeIfPresent(Bool.self, forKey: .metronomeClick) ?? d.metronomeClick
        rhythmFeatures = try c.decodeIfPresent(Set<RhythmFeature>.self, forKey: .rhythmFeatures) ?? d.rhythmFeatures
        rhythmMeasures = try c.decodeIfPresent(Int.self, forKey: .rhythmMeasures) ?? d.rhythmMeasures
        repeatOnFail = try c.decodeIfPresent(Bool.self, forKey: .repeatOnFail) ?? d.repeatOnFail
        keyFifths = try c.decodeIfPresent(Set<Int>.self, forKey: .keyFifths) ?? d.keyFifths
        motion = try c.decodeIfPresent(HandMotion.self, forKey: .motion) ?? d.motion
        leftHandTreble = try c.decodeIfPresent(Bool.self, forKey: .leftHandTreble) ?? d.leftHandTreble
        rhythmOnly = try c.decodeIfPresent(Bool.self, forKey: .rhythmOnly) ?? d.rhythmOnly
        tempoMarks = try c.decodeIfPresent(Set<TempoMark>.self, forKey: .tempoMarks) ?? d.tempoMarks
    }

    func pickKey() -> KeySignature {
        KeySignature(fifths: min(max(keyFifths.randomElement() ?? 0, -7), 7))
    }

    var keysSummary: String {
        let keys = keyFifths.sorted().map { KeySignature(fifths: $0) }
        return keys.count > 3 ? "\(keys.count) tonalidades" : keys.map(\.majorName).joined(separator: ", ")
    }

    var metronomeSummary: String {
        (tempoMarks.isEmpty ? "\(bpm) BPM" : tempoSummary) + " · \(metersSummary)" + (metronome || rhythmOnly ? "" : " · apagado")
    }

    var tempoSummary: String {
        TempoMark.allCases.filter { tempoMarks.contains($0) }.map(\.name).joined(separator: ", ")
    }

    /// Tempo del próximo ejercicio: el típico de uno de los términos elegidos (si hay).
    mutating func pickTempo() {
        if let mark = tempoMarks.randomElement() { bpm = mark.bpm }
    }

    var metersSummary: String {
        Meter.allCases.filter { meters.contains($0) }.map(\.rawValue).joined(separator: ", ")
    }

    /// Compás del próximo ejercicio: al azar entre los elegidos.
    mutating func pickMeter() {
        if let next = meters.randomElement() { meter = next }
    }

    var levelSummary: String {
        guard let level = Level.number(level) else { return "Personalizado" }
        return "Nivel \(level.number)" + (level.matches(self) ? "" : " (modificado)")
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
