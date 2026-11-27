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
    /// Obra del libro para la evaluación final (número de Czerny).
    let piece: Int?
    /// Unidad de ritmo: una línea, cualquier tecla.
    var rhythmOnly = false
    /// Términos de tempo de la unidad (cada sesión sale con uno).
    var tempos: Set<TempoMark> = []

    var id: Int { number }
    var pieceData: Piece? { piece.flatMap(Piece.number) }
    /// Octava exacta desde que se juntan las dos manos.
    var exactOctave: Bool { !rhythmOnly && number > 2 }
    var sessionLength: Int { rhythmOnly ? 12 : (measures == 1 ? 10 : 20) }
    /// Lugar en el camino (1, 2, 3…).
    var position: Int { (Self.ordered.firstIndex { $0.number == number } ?? 0) + 1 }
    /// "Lección 3".
    var label: String { "Lección \(position)" }
    var difficulty: Difficulty {
        Self.path.first { $0.levels.contains(number) }?.difficulty ?? .beginner
    }

    static func label(_ number: Int) -> String { Self.number(number)?.label ?? "" }

    /// Un solo camino de lecciones, de menos a más: lectura (Czerny, 1–16) y ritmo (101–110) intercalados.
    /// No hay que elegir nada: se sigue en orden y cada lección abre la siguiente.
    static let path: [(difficulty: Difficulty, levels: [Int])] = [
        (.beginner, [101, 1, 2, 102, 3]),
        (.beginnerPlus, [4, 103, 5, 6, 104]),
        (.intermediate, [105, 106, 107, 7, 8, 9]),
        (.intermediatePlus, [10, 11, 108, 12, 13]),
        (.advanced, [109, 14, 15, 110, 16]),
    ]

    static let ordered: [Level] = path.flatMap { $0.levels.compactMap { number($0) } }

    static func next(after number: Int) -> Level? {
        guard let i = ordered.firstIndex(where: { $0.number == number }), i + 1 < ordered.count else { return nil }
        return ordered[i + 1]
    }

    static func previous(before number: Int) -> Level? {
        guard let i = ordered.firstIndex(where: { $0.number == number }), i > 0 else { return nil }
        return ordered[i - 1]
    }

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
        settings.rhythmOnly = rhythmOnly
        settings.tempoMarks = tempos
        if let first = TempoMark.allCases.first(where: { tempos.contains($0) }) { settings.bpm = first.bpm }
    }

    /// Si los ajustes siguen siendo exactamente los del nivel (o se cambiaron a mano).
    func matches(_ settings: PracticeSettings) -> Bool {
        var copy = settings
        apply(to: &copy)
        copy.meter = settings.meter // el compás inicial no cuenta: sale al azar entre los del nivel
        if !tempos.isEmpty { copy.bpm = settings.bpm } // el tempo tampoco: sale al azar entre los términos
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
        if rhythmOnly { return rhythmDetails }
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
        if rhythmOnly {
            return [Meter.allCases.filter { meters.contains($0) }.map { $0.rawValue }.joined(separator: ", "),
                    TempoMark.allCases.filter { tempos.contains($0) }.map { $0.name }.joined(separator: ", ")]
                .joined(separator: " · ")
        }
        var parts = [section]
        parts.append(measures == 1 ? "1 compás" : "\(measures) compases")
        parts.append(Meter.allCases.filter { meters.contains($0) }.map(\.rawValue).joined(separator: ", "))
        parts.append(bpm.map { "\($0) BPM" } ?? "sin metrónomo")
        return parts.joined(separator: " · ")
    }

    /// Unidades en el orden de Czerny Op. 599 (Erster Lehrmeister). Primero cada mano sola y luego juntas;
    /// la izquierda lee siempre en clave de fa (las obras del libro con la izquierda en sol se pasan a fa
    /// una octava más grave).
    static let all: [Level] = {
        let c: Set<Int> = [0]
        // Los compases de Czerny; 2/2, 5/4, 3/8, 9/8 y 12/8 se ven en las lecciones de ritmo.
        let allMeters: Set<Meter> = [.twoFour, .threeFour, .fourFour, .sixEight]
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
                  bpm: Int?, repeatOnFail: Bool, piece: Int?) -> Level {
            Level(number: number, title: title, section: section, leftHandTreble: leftTreble, clef: clef,
                  motion: motion, measures: measures, keys: keys, kinds: kinds, features: features, meters: meters,
                  ledgerLines: ledger, accidentals: accidentals, display: names ? .both : .staff,
                  bpm: bpm, repeatOnFail: repeatOnFail, piece: piece)
        }

        return [
            unit(1, "Mano derecha", "Nos. 1–7", clef: .treble, leftTreble: false, motion: .fixed, measures: 1,
                 kinds: [.single], features: [.long], meters: [.fourFour], ledger: false, names: true,
                 bpm: nil, repeatOnFail: true, piece: 1),
            unit(2, "Mano izquierda", "Nos. 1–7", clef: .bass, leftTreble: false, motion: .fixed, measures: 1,
                 kinds: [.single], features: [.long], meters: [.fourFour], ledger: false, names: true,
                 bpm: nil, repeatOnFail: true, piece: 1),
            unit(3, "Las dos manos", "Nos. 1–7", leftTreble: false, motion: .fixed, measures: 1,
                 kinds: [.single], features: [.long], meters: [.fourFour], ledger: false,
                 bpm: nil, repeatOnFail: true, piece: 1),
            unit(4, "Líneas adicionales", "Nos. 2, 4, 6, 7", leftTreble: false, motion: .fixed, measures: 1,
                 kinds: [.single], features: [.long], meters: [.fourFour],
                 bpm: nil, repeatOnFail: true, piece: 2),
            unit(5, "Primeros acordes", "Nos. 8–10", leftTreble: false, motion: .fixed, measures: 1,
                 kinds: [.single, .triad], features: [.long], meters: [.fourFour],
                 bpm: 60, repeatOnFail: true, piece: 10),
            unit(6, "Cinco dedos: corcheas y silencios", "Nos. 11–14", leftTreble: false, motion: .fixed, measures: 1,
                 features: u6, meters: [.fourFour], bpm: 60, repeatOnFail: true, piece: 12),
            unit(7, "Tresillos y semicorcheas", "Nos. 15–18", leftTreble: false, motion: .fixed, measures: 1,
                 features: u7, meters: [.fourFour], bpm: 60, repeatOnFail: true, piece: 18),
            unit(8, "Paso del pulgar y nuevos compases", "Nos. 19–26", leftTreble: false, motion: .octave, measures: 2,
                 features: u8, bpm: 65, repeatOnFail: false, piece: 21),
            unit(9, "Más de una octava", "Nos. 27–31", leftTreble: false, motion: .free, measures: 2,
                 features: u9, bpm: 65, repeatOnFail: false, piece: 28),
            unit(10, "Mano izquierda sola", "Nos. 32–35", clef: .bass, leftTreble: false, motion: .octave, measures: 2,
                 features: u9, bpm: 65, repeatOnFail: false, piece: 32),
            unit(11, "Las dos manos, mano libre", "Nos. 32–35", leftTreble: false, motion: .free, measures: 2,
                 features: u9, bpm: 65, repeatOnFail: false, piece: 32),
            unit(12, "Sostenidos y bemoles", "Nos. 36–38", leftTreble: false, motion: .free, measures: 2,
                 features: u9, accidentals: true, bpm: 70, repeatOnFail: false, piece: 36),
            unit(13, "Sol mayor y Fa mayor", "Nos. 39–42", leftTreble: false, motion: .free, measures: 2,
                 keys: [0, 1, -1], features: u9, accidentals: true, bpm: 70, repeatOnFail: false, piece: 39),
            unit(14, "Silencios, puntillo y nuevas tonalidades", "Nos. 43–57", leftTreble: false, motion: .free, measures: 2,
                 keys: [0, 1, -1, 2, -2], features: u14, accidentals: true, bpm: 75, repeatOnFail: false, piece: 47),
            unit(15, "Ejercicios de velocidad", "Nos. 58–79", leftTreble: false, motion: .free, measures: 2,
                 keys: Set(-3...3), features: allFeatures, accidentals: true, bpm: 85, repeatOnFail: false, piece: 58),
            unit(16, "Tonalidades lejanas", "Nos. 80–100", leftTreble: false, motion: .free, measures: 2,
                 keys: Set(-5...5), features: allFeatures, accidentals: true, bpm: 100, repeatOnFail: false, piece: 94),
        ]
    }()

    static func number(_ n: Int) -> Level? { (all + rhythm).first { $0.number == n } }

    private var rhythmDetails: [String] {
        let figures = (["Negras"] + RhythmFeature.allCases.filter { features.contains($0) && $0 != .slurs }.map { $0.label })
            .joined(separator: ", ")
        var lines = ["Solo ritmo: cualquier tecla del piano o el botón de la pantalla",
                     "Cuenta cuándo empieza y cuánto dura cada figura",
                     "Compases: " + Meter.allCases.filter { meters.contains($0) }.map { $0.rawValue }.joined(separator: ", "),
                     figures]
        for mark in TempoMark.allCases where tempos.contains(mark) {
            lines.append("\(mark.name) (\(mark.bpm) BPM): \(mark.meaning.lowercased())")
        }
        lines.append(repeatOnFail ? "Repite el compás si fallas" : "Sigue aunque falles")
        lines.append("\(sessionLength) ejercicios")
        return lines
    }

    /// Recorrido de ritmo (unidades 101…): figuras, silencios, compases y términos de tempo, de menos a más.
    static let rhythm: [Level] = {
        func unit(_ n: Int, _ title: String, _ section: String, features: Set<RhythmFeature>, meters: Set<Meter>,
                  tempos: Set<TempoMark>, repeatOnFail: Bool = true) -> Level {
            Level(number: 100 + n, title: title, section: section, leftHandTreble: false, clef: .treble,
                  motion: .fixed, measures: 2, keys: [0], kinds: [.single], features: features, meters: meters,
                  ledgerLines: false, accidentals: false, display: .staff, bpm: 80, repeatOnFail: repeatOnFail,
                  piece: nil, rhythmOnly: true, tempos: tempos)
        }
        let simple: Set<Meter> = [.twoFour, .threeFour, .fourFour]
        let every = Set(Meter.allCases)
        let basic: Set<RhythmFeature> = [.long, .rests, .eighths]
        let dotted = basic.union([.dotted, .ties])
        let all = Set(RhythmFeature.allCases).subtracting([.slurs])

        return [
            unit(1, "Negras y blancas", "Ritmo 1", features: [.long], meters: [.fourFour],
                 tempos: [.andante, .moderato]),
            unit(2, "Silencios y redondas", "Ritmo 2", features: [.long, .rests], meters: [.fourFour, .threeFour],
                 tempos: [.adagio, .andante, .moderato]),
            unit(3, "Corcheas", "Ritmo 3", features: basic, meters: simple,
                 tempos: [.adagio, .andante, .moderato]),
            unit(4, "Puntillo y ligaduras", "Ritmo 4", features: dotted, meters: simple,
                 tempos: [.largo, .adagio, .andante, .moderato]),
            unit(5, "Compases de corchea: 3/8 y 6/8", "Ritmo 5", features: dotted, meters: [.threeEight, .sixEight],
                 tempos: [.andante, .moderato, .allegretto]),
            unit(6, "Semicorcheas", "Ritmo 6", features: dotted.union([.sixteenths]), meters: simple,
                 tempos: [.largo, .adagio, .andante]),
            unit(7, "Tresillos y saltillo", "Ritmo 7", features: dotted.union([.triplets, .saltillo]),
                 meters: simple.union([.sixEight]), tempos: [.adagio, .andante, .moderato]),
            unit(8, "2/2, 5/4, 9/8 y 12/8", "Ritmo 8", features: dotted, meters: [.twoTwo, .fiveFour, .nineEight, .twelveEight],
                 tempos: [.andante, .moderato, .allegretto], repeatOnFail: false),
            unit(9, "Tempos rápidos", "Ritmo 9", features: dotted, meters: simple.union([.twoTwo, .sixEight]),
                 tempos: [.allegro, .vivace, .presto], repeatOnFail: false),
            unit(10, "Todo junto", "Ritmo 10", features: all, meters: every,

                 tempos: [.grave, .largo, .adagio, .andante, .moderato, .allegretto, .allegro], repeatOnFail: false),
        ]
    }()
}

/// Nivel de dificultad de un tramo del camino.
enum Difficulty: Int, CaseIterable {
    case beginner, beginnerPlus, intermediate, intermediatePlus, advanced

    var name: String {
        switch self {
        case .beginner: "Principiante"
        case .beginnerPlus: "Principiante avanzado"
        case .intermediate: "Intermedio"
        case .intermediatePlus: "Intermedio avanzado"
        case .advanced: "Avanzado"
        }
    }
}

extension Difficulty {
    /// Práctica libre de lectura: lo de la última unidad de lectura de este nivel (todo lo anterior incluido).
    func readingSettings(from base: PracticeSettings) -> PracticeSettings {
        let unit = [Difficulty.beginner: 3, .beginnerPlus: 6, .intermediate: 9, .intermediatePlus: 13, .advanced: 16][self] ?? 3
        var settings = Level.number(unit)?.settings(from: base) ?? base
        settings.level = 0
        settings.sessionLength = 20
        return settings
    }

    /// Práctica de ritmo: lo de la última lección de ritmo de este nivel (todo lo anterior incluido).
    func rhythmSettings(from base: PracticeSettings) -> PracticeSettings {
        let lesson = [Difficulty.beginner: 102, .beginnerPlus: 104, .intermediate: 107, .intermediatePlus: 108, .advanced: 110][self] ?? 102
        var settings = Level.number(lesson)?.settings(from: base) ?? base
        if self == .intermediatePlus, let previous = Level.number(107) {
            // Compases nuevos con todas las figuras ya vistas.
            settings.rhythmFeatures.formUnion(previous.features)
            settings.meters.formUnion(previous.meters)
            settings.tempoMarks.formUnion(previous.tempos)
        }
        settings.level = 0
        settings.sessionLength = 20
        return settings
    }
}
