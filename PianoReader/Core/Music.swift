import Foundation

enum Letter: Int, CaseIterable, Codable {
    case c, d, e, f, g, a, b

    var semitone: Int { [0, 2, 4, 5, 7, 9, 11][rawValue] }
    var english: String { ["C", "D", "E", "F", "G", "A", "B"][rawValue] }
    var solfege: String { ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"][rawValue] }
}

enum Accidental: Int, Codable {
    case flat = -1, natural = 0, sharp = 1

    var symbol: String {
        switch self {
        case .flat: "♭"
        case .natural: ""
        case .sharp: "♯"
        }
    }
}

enum NamingStyle: String, CaseIterable, Identifiable, Codable {
    case english, solfege
    var id: String { rawValue }
    var label: String { self == .english ? "C D E" : "Do Re Mi" }
}

/// Nota escrita. `diatonic` = octava * 7 + letra (C4 = 28).
struct Note: Hashable, Codable {
    let letter: Letter
    let accidental: Accidental
    let octave: Int

    init(diatonic: Int, accidental: Accidental = .natural) {
        letter = Letter(rawValue: diatonic % 7)!
        octave = diatonic / 7
        self.accidental = accidental
    }

    var diatonic: Int { octave * 7 + letter.rawValue }
    var midi: Int { (octave + 1) * 12 + letter.semitone + accidental.rawValue }

    func name(_ style: NamingStyle, octave showOctave: Bool) -> String {
        let base = (style == .english ? letter.english : letter.solfege) + accidental.symbol
        return showOctave ? base + "\(octave)" : base
    }

    /// Nombre de una tecla tocada (sin ortografía: usa sostenidos).
    static func pitchName(midi: Int, style: NamingStyle, octave: Bool) -> String {
        let pc = ((midi % 12) + 12) % 12
        let en = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let so = ["Do", "Do♯", "Re", "Re♯", "Mi", "Fa", "Fa♯", "Sol", "Sol♯", "La", "La♯", "Si"]
        let base = style == .english ? en[pc] : so[pc]
        return octave ? base + "\(midi / 12 - 1)" : base
    }
}

enum Clef: String, Codable {
    case treble, bass

    /// Línea inferior del pentagrama: E4 en sol, G2 en fa.
    var bottomLine: Int { self == .treble ? 30 : 18 }
    var label: String { self == .treble ? "Sol" : "Fa" }

    func range(ledgerLines: Bool) -> ClosedRange<Int> {
        switch self {
        case .treble: ledgerLines ? 26...42 : 30...38 // A3–C6 / E4–F5
        case .bass: ledgerLines ? 14...30 : 18...26   // C2–E4 / G2–A3
        }
    }
}
