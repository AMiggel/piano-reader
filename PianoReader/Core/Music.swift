import Foundation

enum Letter: Int, CaseIterable, Codable {
    case c, d, e, f, g, a, b

    var semitone: Int { [0, 2, 4, 5, 7, 9, 11][rawValue] }
    var english: String { ["C", "D", "E", "F", "G", "A", "B"][rawValue] }
    var solfege: String { ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"][rawValue] }
}

enum Accidental: Int, Codable {
    case flat = -1, natural = 0, sharp = 1

    /// Para nombres (F♯, B♭, C).
    var symbol: String {
        switch self {
        case .flat: "♭"
        case .natural: ""
        case .sharp: "♯"
        }
    }

    /// Signo escrito en el pentagrama (incluye el becuadro).
    var mark: String {
        switch self {
        case .flat: "♭"
        case .natural: "♮"
        case .sharp: "♯"
        }
    }
}

/// Armadura: `fifths` > 0 sostenidos, < 0 bemoles (−7…7).
struct KeySignature: Hashable {
    let fifths: Int

    static let all = (-7...7).map(KeySignature.init(fifths:))
    private static let sharpOrder: [Letter] = [.f, .c, .g, .d, .a, .e, .b]
    private static let flatOrder: [Letter] = [.b, .e, .a, .d, .g, .c, .f]

    var letters: [Letter] {
        fifths >= 0 ? Array(Self.sharpOrder.prefix(fifths)) : Array(Self.flatOrder.prefix(-fifths))
    }

    func accidental(for letter: Letter) -> Accidental {
        letters.contains(letter) ? (fifths > 0 ? .sharp : .flat) : .natural
    }

    var majorName: String {
        ["Do♭", "Sol♭", "Re♭", "La♭", "Mi♭", "Si♭", "Fa", "Do", "Sol", "Re", "La", "Mi", "Si", "Fa♯", "Do♯"][fifths + 7]
    }

    var minorName: String {
        ["La♭", "Mi♭", "Si♭", "Fa", "Do", "Sol", "Re", "La", "Mi", "Si", "Fa♯", "Do♯", "Sol♯", "Re♯", "La♯"][fifths + 7]
    }

    var label: String { "\(majorName) mayor / \(minorName) menor" }
    var signLabel: String { fifths == 0 ? "sin alteraciones" : "\(abs(fifths))\(fifths > 0 ? "♯" : "♭")" }

    /// Posiciones (pasos desde la línea inferior) de los signos de la armadura.
    func staffSteps(_ clef: Clef) -> [Int] {
        let treble = fifths >= 0 ? [8, 5, 9, 6, 3, 7, 4] : [4, 7, 3, 6, 2, 5, 1]
        let offset = clef == .treble ? 0 : -2
        return treble.prefix(abs(fifths)).map { $0 + offset }
    }

    /// Nota de la tonalidad en esa posición (sin signo escrito).
    func note(_ diatonic: Int) -> Note {
        Note(diatonic: diatonic, accidental: accidental(for: Letter(rawValue: diatonic % 7)!))
    }

    /// Alteración accidental (♯ ♭ ♮) que se aparta de la armadura, sin dobles ni E♯/B♯/C♭/F♭ fuera de la armadura.
    func altered(_ diatonic: Int) -> Note {
        let letter = Letter(rawValue: diatonic % 7)!
        let inKey = accidental(for: letter)
        var options: [Accidental] = [.sharp, .natural, .flat].filter { $0 != inKey }
        if letter == .e || letter == .b { options.removeAll { $0 == .sharp } }
        if letter == .c || letter == .f { options.removeAll { $0 == .flat } }
        return Note(diatonic: diatonic, accidental: options.randomElement() ?? inKey)
    }

    /// Escribe una tecla tocada como nota de esta tonalidad (F♯ en Sol mayor, G♭ en Re♭ mayor…).
    func spell(midi: Int) -> Note {
        let pc = ((midi % 12) + 12) % 12
        var choice: (Letter, Accidental)?
        for letter in Letter.allCases where (letter.semitone + accidental(for: letter).rawValue + 12) % 12 == pc {
            choice = (letter, accidental(for: letter))
        }
        if choice == nil, let letter = Letter.allCases.first(where: { $0.semitone == pc }) {
            choice = (letter, .natural)
        }
        if choice == nil {
            let sharp = fifths >= 0
            let target = (pc + (sharp ? 11 : 1)) % 12
            if let letter = Letter.allCases.first(where: { $0.semitone == target }) {
                choice = (letter, sharp ? .sharp : .flat)
            }
        }
        let (letter, acc) = choice ?? (.c, .natural)
        let octave = (midi - letter.semitone - acc.rawValue) / 12 - 1
        return Note(diatonic: octave * 7 + letter.rawValue, accidental: acc)
    }

    /// Signo a escribir junto a cada nota (nil = ninguno). Regla del compás: la alteración dura hasta la barra.
    func displayed(_ notes: [Note]) -> [Accidental?] {
        var state: [Int: Accidental] = [:]
        return notes.map { note in
            let current = state[note.diatonic] ?? accidental(for: note.letter)
            state[note.diatonic] = note.accidental
            return note.accidental == current ? nil : note.accidental
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

    /// La misma nota movida a la octava más cercana a `diatonic` (para mostrarla junto a la nota pedida).
    func folded(near target: Int) -> Note {
        let shift = Int((Double(target - diatonic) / 7).rounded())
        return Note(diatonic: diatonic + shift * 7, accidental: accidental)
    }
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
