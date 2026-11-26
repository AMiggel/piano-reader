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
    /// Como en el libro, siempre con las dos manos; octava exacta desde la unidad 2.
    var clef: ClefChoice { .both }
    var exactOctave: Bool { number > 1 }
    var sessionLength: Int { number <= 5 ? 10 : 20 }

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
        var lines = ["Czerny Op. 599, \(section)", motion.detail,
                     leftHandTreble ? "Las dos manos en clave de sol" : "Izquierda en clave de fa",
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

    /// Unidades en el orden de Czerny Op. 599 (Erster Lehrmeister). Las dos manos como en el libro;
    /// la izquierda lee en clave de sol hasta la unidad 7 (Nos. 1–31).
    static let all: [Level] = {
        let c: Set<Int> = [0]
        let simple: Set<Meter> = [.twoFour, .threeFour, .fourFour]
        let allMeters = Set(Meter.allCases)
        let u4: Set<RhythmFeature> = [.long, .eighths, .rests, .slurs]
        let u5 = u4.union([.triplets, .sixteenths])
        let u6 = u5.union([.dotted])
        let u7 = u6.union([.ties])
        let u11 = u7.union([.saltillo])
        let allFeatures = Set(RhythmFeature.allCases)
        let thirds: Set<ExerciseKind> = [.single, .interval]
        let allKinds: Set<ExerciseKind> = [.single, .interval, .triad]

        return [
            Level(number: 1, title: "Primeras notas", section: "Nos. 1–7", leftHandTreble: true, motion: .fixed,
                  measures: 1, keys: c, kinds: [.single], features: [.long], meters: [.fourFour],
                  ledgerLines: false, accidentals: false, display: .both, bpm: nil, repeatOnFail: true),
            Level(number: 2, title: "Líneas adicionales", section: "Nos. 2, 4, 6, 7", leftHandTreble: true, motion: .fixed,
                  measures: 1, keys: c, kinds: [.single], features: [.long], meters: [.fourFour],
                  ledgerLines: true, accidentals: false, display: .staff, bpm: nil, repeatOnFail: true),
            Level(number: 3, title: "Primeros acordes", section: "Nos. 8–10", leftHandTreble: true, motion: .fixed,
                  measures: 1, keys: c, kinds: [.single, .triad], features: [.long], meters: [.fourFour],
                  ledgerLines: true, accidentals: false, display: .staff, bpm: 60, repeatOnFail: true),
            Level(number: 4, title: "Cinco dedos: corcheas y silencios", section: "Nos. 11–14", leftHandTreble: true, motion: .fixed,
                  measures: 1, keys: c, kinds: allKinds, features: u4, meters: [.fourFour],
                  ledgerLines: true, accidentals: false, display: .staff, bpm: 60, repeatOnFail: true),
            Level(number: 5, title: "Tresillos y semicorcheas", section: "Nos. 15–18", leftHandTreble: true, motion: .fixed,
                  measures: 1, keys: c, kinds: allKinds, features: u5, meters: [.fourFour],
                  ledgerLines: true, accidentals: false, display: .staff, bpm: 60, repeatOnFail: true),
            Level(number: 6, title: "Paso del pulgar y nuevos compases", section: "Nos. 19–26", leftHandTreble: true, motion: .octave,
                  measures: 2, keys: c, kinds: allKinds, features: u6, meters: allMeters,
                  ledgerLines: true, accidentals: false, display: .staff, bpm: 65, repeatOnFail: false),
            Level(number: 7, title: "Más de una octava", section: "Nos. 27–31", leftHandTreble: true, motion: .free,
                  measures: 2, keys: c, kinds: allKinds, features: u7, meters: allMeters,
                  ledgerLines: true, accidentals: false, display: .staff, bpm: 65, repeatOnFail: false),
            Level(number: 8, title: "Clave de fa", section: "Nos. 32–35", leftHandTreble: false, motion: .free,
                  measures: 2, keys: c, kinds: allKinds, features: u7, meters: allMeters,
                  ledgerLines: true, accidentals: false, display: .staff, bpm: 65, repeatOnFail: false),
            Level(number: 9, title: "Sostenidos y bemoles", section: "Nos. 36–38", leftHandTreble: false, motion: .free,
                  measures: 2, keys: c, kinds: allKinds, features: u7, meters: allMeters,
                  ledgerLines: true, accidentals: true, display: .staff, bpm: 70, repeatOnFail: false),
            Level(number: 10, title: "Sol mayor y Fa mayor", section: "Nos. 39–42", leftHandTreble: false, motion: .free,
                  measures: 2, keys: [0, 1, -1], kinds: allKinds, features: u7, meters: allMeters,
                  ledgerLines: true, accidentals: true, display: .staff, bpm: 70, repeatOnFail: false),
            Level(number: 11, title: "Silencios, puntillo y nuevas tonalidades", section: "Nos. 43–57", leftHandTreble: false, motion: .free,
                  measures: 2, keys: [0, 1, -1, 2, -2], kinds: allKinds, features: u11, meters: allMeters,
                  ledgerLines: true, accidentals: true, display: .staff, bpm: 75, repeatOnFail: false),
            Level(number: 12, title: "Ejercicios de velocidad", section: "Nos. 58–79", leftHandTreble: false, motion: .free,
                  measures: 2, keys: Set(-3...3), kinds: allKinds, features: allFeatures, meters: allMeters,
                  ledgerLines: true, accidentals: true, display: .staff, bpm: 85, repeatOnFail: false),
            Level(number: 13, title: "Tonalidades lejanas", section: "Nos. 80–100", leftHandTreble: false, motion: .free,
                  measures: 2, keys: Set(-5...5), kinds: allKinds, features: allFeatures, meters: allMeters,
                  ledgerLines: true, accidentals: true, display: .staff, bpm: 100, repeatOnFail: false),
        ]
    }()

    static func number(_ n: Int) -> Level? { all.first { $0.number == n } }
}
