import Foundation

/// Niveles: ajustes predefinidos que van sumando dificultad. El nombre de las notas (C D E / Do Re Mi)
/// no lo toca ningún nivel: es preferencia del usuario.
struct Level: Identifiable {
    let number: Int
    let title: String
    let clef: ClefChoice
    let measures: Int
    let keys: Set<Int>
    let kinds: Set<ExerciseKind>
    let features: Set<RhythmFeature>
    let meters: Set<Meter>
    let ledgerLines: Bool
    let accidentals: Bool
    let exactOctave: Bool
    let display: DisplayMode
    /// nil = sin metrónomo.
    let bpm: Int?
    let repeatOnFail: Bool

    var id: Int { number }
    var sessionLength: Int { number <= 4 ? 10 : 20 }
    /// Como en Czerny: cinco dedos (1–4), paso del pulgar en una octava (5–6), luego libre.
    var motion: HandMotion { number <= 4 ? .fixed : (number <= 6 ? .octave : .free) }

    func apply(to settings: inout PracticeSettings) {
        settings.level = number
        settings.clef = clef
        settings.motion = motion
        settings.rhythmMeasures = measures
        settings.keyFifths = keys
        settings.kinds = kinds
        settings.rhythmFeatures = features
        settings.meters = meters
        settings.meter = meters.contains(.fourFour) ? .fourFour : (meters.first ?? .fourFour)
        settings.ledgerLines = ledgerLines
        settings.accidentals = accidentals
        settings.exactOctave = exactOctave
        settings.display = display
        settings.metronome = bpm != nil
        settings.bpm = bpm ?? 60
        settings.repeatOnFail = repeatOnFail
        settings.sessionLength = sessionLength
    }

    /// Si los ajustes siguen siendo exactamente los del nivel (o se cambiaron a mano).
    func matches(_ settings: PracticeSettings) -> Bool {
        var copy = settings
        apply(to: &copy)
        copy.meter = settings.meter // el compás inicial no cuenta: sale al azar entre los del nivel
        return copy == settings
    }

    /// Ajustes para jugar el nivel: los del nivel sobre tus preferencias (nombres, clic).
    func settings(from base: PracticeSettings) -> PracticeSettings {
        var copy = base
        apply(to: &copy)
        return copy
    }

    /// Lo que incluye el nivel, línea por línea.
    var details: [String] {
        let keyText = keys.count >= 15 ? "Todas las tonalidades"
            : keys.sorted().map { KeySignature(fifths: $0).majorName }.joined(separator: ", ")
        let kindText = ExerciseKind.selectable.filter { kinds.contains($0) }.map(\.label).joined(separator: ", ")
        let figures = (["Negras"] + RhythmFeature.allCases.filter { features.contains($0) }.map(\.label))
            .joined(separator: ", ")
        var reading: [String] = []
        if exactOctave { reading.append("Octava exacta") }
        if accidentals { reading.append("Alteraciones") }
        if ledgerLines { reading.append("Líneas adicionales") }
        var lines = [motion.detail, keyText, kindText, figures]
        if !reading.isEmpty { lines.append(reading.joined(separator: ", ")) }
        if bpm != nil { lines.append(repeatOnFail ? "Repite el compás si fallas" : "Sigue aunque falles") }
        if display == .both { lines.append("Con nombre de nota") }
        lines.append("\(sessionLength) ejercicios")
        return lines
    }

    var summary: String {
        var parts = [clef.detail]
        parts.append(measures == 1 ? "1 compás" : "\(measures) compases")
        parts.append(Meter.allCases.filter { meters.contains($0) }.map(\.rawValue).joined(separator: ", "))
        parts.append(bpm.map { "\($0) BPM" } ?? "sin metrónomo")
        return parts.joined(separator: " · ")
    }

    static let all: [Level] = {
        let basic: Set<RhythmFeature> = [.long]
        let withRests = basic.union([.rests])
        let l4 = withRests.union([.eighths])
        let l5 = l4.union([.ties])
        let l6 = l5.union([.dotted, .slurs])
        let l7 = l6.union([.sixteenths, .saltillo])
        let l8 = l7.union([.triplets])
        let simple: Set<Meter> = [.twoFour, .threeFour, .fourFour]
        let allKinds: Set<ExerciseKind> = [.single, .interval, .triad]

        return [
            Level(number: 1, title: "Primer contacto", clef: .treble, measures: 1, keys: [0],
                  kinds: [.single], features: basic, meters: [.fourFour],
                  ledgerLines: false, accidentals: false, exactOctave: false, display: .both,
                  bpm: nil, repeatOnFail: true),
            Level(number: 2, title: "Clave de fa y sin ayudas", clef: .bass, measures: 1, keys: [0],
                  kinds: [.single], features: withRests, meters: [.fourFour],
                  ledgerLines: false, accidentals: false, exactOctave: true, display: .staff,
                  bpm: nil, repeatOnFail: true),
            Level(number: 3, title: "Dos manos y 3/4", clef: .both, measures: 1, keys: [0],
                  kinds: [.single], features: withRests, meters: simple,
                  ledgerLines: false, accidentals: false, exactOctave: true, display: .staff,
                  bpm: 60, repeatOnFail: true),
            Level(number: 4, title: "Grupo 1 e intervalos", clef: .both, measures: 1, keys: [0, 1, -1],
                  kinds: [.single, .interval], features: l4, meters: simple,
                  ledgerLines: false, accidentals: false, exactOctave: true, display: .staff,
                  bpm: 65, repeatOnFail: true),
            Level(number: 5, title: "Acordes y fluidez", clef: .both, measures: 2, keys: [0, 1, -1],
                  kinds: allKinds, features: l5, meters: simple,
                  ledgerLines: false, accidentals: false, exactOctave: true, display: .staff,
                  bpm: 70, repeatOnFail: false),
            Level(number: 6, title: "Grupo 2 (sostenidos)", clef: .both, measures: 2, keys: [2, 3, 4],
                  kinds: allKinds, features: l6, meters: simple,
                  ledgerLines: false, accidentals: true, exactOctave: true, display: .staff,
                  bpm: 75, repeatOnFail: false),
            Level(number: 7, title: "Grupo 3 (bemoles)", clef: .both, measures: 2, keys: [-2, -3, -4],
                  kinds: allKinds, features: l7, meters: simple,
                  ledgerLines: true, accidentals: true, exactOctave: true, display: .staff,
                  bpm: 80, repeatOnFail: false),
            Level(number: 8, title: "Compás compuesto", clef: .both, measures: 2, keys: Set(-4...4),
                  kinds: allKinds, features: l8, meters: Set(Meter.allCases),
                  ledgerLines: true, accidentals: true, exactOctave: true, display: .staff,
                  bpm: 85, repeatOnFail: false),
            Level(number: 9, title: "Armaduras complejas", clef: .both, measures: 2, keys: [5, 6, -5, -6],
                  kinds: allKinds, features: Set(RhythmFeature.allCases), meters: Set(Meter.allCases),
                  ledgerLines: true, accidentals: true, exactOctave: true, display: .staff,
                  bpm: 95, repeatOnFail: false),
            Level(number: 10, title: "Primera vista total", clef: .both, measures: 2, keys: Set(-7...7),
                  kinds: allKinds, features: Set(RhythmFeature.allCases), meters: Set(Meter.allCases),
                  ledgerLines: true, accidentals: true, exactOctave: true, display: .staff,
                  bpm: 110, repeatOnFail: false),
        ]
    }()

    static func number(_ n: Int) -> Level? { all.first { $0.number == n } }
}
