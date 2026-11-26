import Foundation

/// Unidades (niveles) que siguen el orden de Czerny Op. 599. El nombre de las notas (C D E / Do Re Mi)
/// no lo toca ningún nivel: es preferencia del usuario.
struct Level: Identifiable {
    let number: Int
    let title: String
    /// Números del libro que cubre.
    let section: String
    /// La izquierda en clave de sol (Czerny hasta el No. 31).
    let leftHandTreble: Bool
    let clef: ClefChoice
    let motion: HandMotion
    let measures: Int
    let keys: Set<Int>
    let kinds: Set<ExerciseKind>
    let features: Set<RhythmFeature>
    let meters: Set<Meter>
    let ledgerLines: Bool
    let accidentals: Bool
    let display: DisplayMode
    /// nil = sin metrónomo.
    let bpm: Int?
    let repeatOnFail: Bool

    var id: Int { number }
    /// Octava exacta desde que se juntan las dos manos.
    var exactOctave: Bool { number > 2 }
    var sessionLength: Int { measures == 1 ? 10 : 20 }

    func apply(to settings: inout PracticeSettings) {
        settings.level = number
        settings.clef = clef
        settings.motion = motion
        settings.leftHandTreble = leftHandTreble
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
        let handText: String = switch clef {
        case .treble: "Mano derecha sola, clave de sol"
        case .bass: leftHandTreble ? "Mano izquierda sola, en clave de sol" : "Mano izquierda sola, clave de fa"
        case .both: leftHandTreble ? "Las dos manos en clave de sol" : "Derecha en sol, izquierda en fa"
        }
        var lines = ["Czerny Op. 599, \(section)", motion.detail,
                     handText,
                     keyText, kindText, figures]
        if !reading.isEmpty { lines.append(reading.joined(separator: ", ")) }
        if bpm != nil { lines.append(repeatOnFail ? "Repite el compás si fallas" : "Sigue aunque falles") }
        if display == .both { lines.append("Con nombre de nota") }
        lines.append("\(sessionLength) ejercicios")
        return lines
    }

    var summary: String {
        var parts = [section]
        parts.append(measures == 1 ? "1 compás" : "\(measures) compases")
        parts.append(Meter.allCases.filter { meters.contains($0) }.map(\.rawValue).joined(separator: ", "))
        parts.append(bpm.map { "\($0) BPM" } ?? "sin metrónomo")
        return parts.joined(separator: " · ")
    }

    /// Unidades en el orden de Czerny Op. 599 (Erster Lehrmeister). Primero cada mano sola y luego juntas;
    /// la izquierda lee en clave de sol hasta los Nos. 31, como en el libro, y la clave de fa se presenta
    /// primero con la izquierda sola.
    static let all: [Level] = {
        let c: Set<Int> = [0]
        let allMeters = Set(Meter.allCases)
        let u6: Set<RhythmFeature> = [.long, .eighths, .rests, .slurs]
        let u7 = u6.union([.triplets, .sixteenths])
        let u8 = u7.union([.dotted])
        let u9 = u8.union([.ties])
        let u14 = u9.union([.saltillo])
        let allFeatures = Set(RhythmFeature.allCases)
        let allKinds: Set<ExerciseKind> = [.single, .interval, .triad]

        func unit(_ number: Int, _ title: String, _ section: String, clef: ClefChoice = .both,
                  leftTreble: Bool, motion: HandMotion, measures: Int, keys: Set<Int> = c,
                  kinds: Set<ExerciseKind> = allKinds, features: Set<RhythmFeature>, meters: Set<Meter> = allMeters,
                  ledger: Bool = true, accidentals: Bool = false, names: Bool = false,
                  bpm: Int?, repeatOnFail: Bool) -> Level {
            Level(number: number, title: title, section: section, leftHandTreble: leftTreble, clef: clef,
                  motion: motion, measures: measures, keys: keys, kinds: kinds, features: features, meters: meters,
                  ledgerLines: ledger, accidentals: accidentals, display: names ? .both : .staff,
                  bpm: bpm, repeatOnFail: repeatOnFail)
        }

        return [
            unit(1, "Mano derecha", "Nos. 1–7", clef: .treble, leftTreble: true, motion: .fixed, measures: 1,
                 kinds: [.single], features: [.long], meters: [.fourFour], ledger: false, names: true,
                 bpm: nil, repeatOnFail: true),
            unit(2, "Mano izquierda", "Nos. 1–7", clef: .bass, leftTreble: true, motion: .fixed, measures: 1,
                 kinds: [.single], features: [.long], meters: [.fourFour], ledger: false, names: true,
                 bpm: nil, repeatOnFail: true),
            unit(3, "Las dos manos", "Nos. 1–7", leftTreble: true, motion: .fixed, measures: 1,
                 kinds: [.single], features: [.long], meters: [.fourFour], ledger: false,
                 bpm: nil, repeatOnFail: true),
            unit(4, "Líneas adicionales", "Nos. 2, 4, 6, 7", leftTreble: true, motion: .fixed, measures: 1,
                 kinds: [.single], features: [.long], meters: [.fourFour],
                 bpm: nil, repeatOnFail: true),
            unit(5, "Primeros acordes", "Nos. 8–10", leftTreble: true, motion: .fixed, measures: 1,
                 kinds: [.single, .triad], features: [.long], meters: [.fourFour],
                 bpm: 60, repeatOnFail: true),
            unit(6, "Cinco dedos: corcheas y silencios", "Nos. 11–14", leftTreble: true, motion: .fixed, measures: 1,
                 features: u6, meters: [.fourFour], bpm: 60, repeatOnFail: true),
            unit(7, "Tresillos y semicorcheas", "Nos. 15–18", leftTreble: true, motion: .fixed, measures: 1,
                 features: u7, meters: [.fourFour], bpm: 60, repeatOnFail: true),
            unit(8, "Paso del pulgar y nuevos compases", "Nos. 19–26", leftTreble: true, motion: .octave, measures: 2,
                 features: u8, bpm: 65, repeatOnFail: false),
            unit(9, "Más de una octava", "Nos. 27–31", leftTreble: true, motion: .free, measures: 2,
                 features: u9, bpm: 65, repeatOnFail: false),
            unit(10, "Clave de fa: mano izquierda", "Nos. 32–35", clef: .bass, leftTreble: false, motion: .octave, measures: 2,
                 features: u9, bpm: 65, repeatOnFail: false),
            unit(11, "Clave de fa: las dos manos", "Nos. 32–35", leftTreble: false, motion: .free, measures: 2,
                 features: u9, bpm: 65, repeatOnFail: false),
            unit(12, "Sostenidos y bemoles", "Nos. 36–38", leftTreble: false, motion: .free, measures: 2,
                 features: u9, accidentals: true, bpm: 70, repeatOnFail: false),
            unit(13, "Sol mayor y Fa mayor", "Nos. 39–42", leftTreble: false, motion: .free, measures: 2,
                 keys: [0, 1, -1], features: u9, accidentals: true, bpm: 70, repeatOnFail: false),
            unit(14, "Silencios, puntillo y nuevas tonalidades", "Nos. 43–57", leftTreble: false, motion: .free, measures: 2,
                 keys: [0, 1, -1, 2, -2], features: u14, accidentals: true, bpm: 75, repeatOnFail: false),
            unit(15, "Ejercicios de velocidad", "Nos. 58–79", leftTreble: false, motion: .free, measures: 2,
                 keys: Set(-3...3), features: allFeatures, accidentals: true, bpm: 85, repeatOnFail: false),
            unit(16, "Tonalidades lejanas", "Nos. 80–100", leftTreble: false, motion: .free, measures: 2,
                 keys: Set(-5...5), features: allFeatures, accidentals: true, bpm: 100, repeatOnFail: false),
        ]
    }()

    static func number(_ n: Int) -> Level? { all.first { $0.number == n } }
}
