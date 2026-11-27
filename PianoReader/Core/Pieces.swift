import Foundation

/// Una obra de Czerny Op. 599 transcrita a texto (dominio público).
///
/// Notación por mano: compases separados por "|", figuras por espacios.
/// Figura = alturas unidas por "+" (o "r" para silencio) + "/" + duración (1, 2, 4, 8, 16),
/// con "." para puntillo, "t" para tresillo y "~" al final si se liga con la siguiente.
/// Las alturas se escriben como suenan (con las alteraciones de la armadura): C4 = do central.
struct Piece {
    let number: Int
    let meter: Meter
    let keyFifths: Int
    let rightClef: Clef
    let leftClef: Clef
    let right: String
    let left: String

    var title: String { "Czerny Op. 599, No. \(number)" }
    var key: KeySignature { KeySignature(fifths: keyFifths) }

    /// La obra completa dividida en tramos de `chunk` compases, para tocarlos uno detrás de otro.
    /// `hands`: derecha, izquierda o ambas.
    /// `leftInBass`: si la izquierda del libro va en clave de sol, se escribe en clave de fa una octava más grave.
    func exercises(hands: ClefChoice, chunk: Int = 2, leftInBass: Bool = true) -> [RhythmExercise] {
        let rh = Self.parse(right, meter: meter)
        var lh = Self.parse(left, meter: meter)
        var leftClef = leftClef
        if leftInBass && leftClef == .treble {
            leftClef = .bass
            lh = lh.map { measure in
                measure.map { token in
                    Token(pitches: token.pitches.map { Note(diatonic: $0.diatonic - 7, accidental: $0.accidental) },
                          item: token.item, tied: token.tied)
                }
            }
        }
        let measures = max(rh.count, lh.count)
        var result: [RhythmExercise] = []
        var start = 0
        while start < measures {
            let count = min(chunk, measures - start)
            var voices: [Voice] = []
            if hands != .bass { voices.append(Self.voice(rh, from: start, count: count, clef: rightClef, meter: meter)) }
            if hands != .treble { voices.append(Self.voice(lh, from: start, count: count, clef: leftClef, meter: meter)) }
            result.append(RhythmExercise(key: key, meter: meter, measures: count, voices: voices))
            start += count
        }
        return result
    }

    // MARK: - Lectura del texto

    struct Token {
        let pitches: [Note]
        let item: CellItem
        let tied: Bool
    }

    static func parse(_ text: String, meter: Meter) -> [[Token]] {
        text.split(separator: "|").map { measure in
            measure.split(separator: " ").compactMap { token($0) }
        }
    }

    private static func token(_ raw: Substring) -> Token? {
        var s = String(raw).trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, let slash = s.firstIndex(of: "/") else { return nil }
        var tied = false
        if s.hasSuffix("~") { tied = true; s.removeLast() }
        let head = String(s[..<slash])
        var dur = String(s[s.index(after: slash)...])
        var dotted = false
        var triplet = false
        if dur.hasSuffix(".") { dotted = true; dur.removeLast() }
        if dur.hasSuffix("t") { triplet = true; dur.removeLast() }
        let value: NoteValue
        switch dur {
        case "1": value = .whole
        case "2": value = .half
        case "4": value = .quarter
        case "8": value = .eighth
        case "16": value = .sixteenth
        default: return nil
        }
        if head == "r" {
            return Token(pitches: [], item: CellItem(value: value, dotted: dotted, triplet: triplet, rest: true), tied: false)
        }
        let notes = head.split(separator: "+").compactMap { pitch($0) }.sorted { $0.diatonic < $1.diatonic }
        guard !notes.isEmpty else { return nil }
        return Token(pitches: notes, item: CellItem(value: value, dotted: dotted, triplet: triplet), tied: tied)
    }

    /// "C4", "F#5", "Bb3".
    private static func pitch(_ raw: Substring) -> Note? {
        let letters: [Character: Int] = ["C": 0, "D": 1, "E": 2, "F": 3, "G": 4, "A": 5, "B": 6]
        var chars = Array(raw)
        guard let first = chars.first, let letter = letters[first] else { return nil }
        chars.removeFirst()
        var accidental = Accidental.natural
        if chars.first == "#" { accidental = .sharp; chars.removeFirst() }
        else if chars.first == "b" { accidental = .flat; chars.removeFirst() }
        guard let octave = Int(String(chars)) else { return nil }
        return Note(diatonic: octave * 7 + letter, accidental: accidental)
    }

    /// Eventos de unos compases, con corchetes por tiempo y tresillos agrupados.
    private static func voice(_ measures: [[Token]], from start: Int, count: Int, clef: Clef, meter: Meter) -> Voice {
        let beat = meter.beatTicks
        var events: [RhythmEvent] = []
        var group = 0
        var lastGroupKey: Int?

        for m in 0..<count where start + m < measures.count {
            var pos = 0
            for token in measures[start + m] {
                let tick = m * meter.measureTicks + pos
                var event = RhythmEvent(tick: tick, item: token.item, measure: m, cellStart: pos % beat == 0)
                event.notes = token.pitches
                let beatIndex = tick / beat
                if !token.item.rest && token.item.value.beams > 0 {
                    if lastGroupKey != beatIndex { group += 1; lastGroupKey = beatIndex }
                    event.beamGroup = group
                } else {
                    lastGroupKey = nil
                }
                if token.item.triplet { event.tupletGroup = 10_000 + beatIndex * 4 + (tick % beat) / max(token.item.ticks * 3, 1) }
                if token.tied { event.tiedToNext = true }
                if let previous = events.last, previous.tiedToNext {
                    event.tiedFromPrevious = true
                }
                events.append(event)
                pos += token.item.ticks
            }
        }
        // Una ligadura que cruza el final del tramo no tiene a quién unirse.
        if var last = events.last, last.tiedToNext {
            last.tiedToNext = false
            events[events.count - 1] = last
        }
        // Grupos de corchete de una sola nota: sin corchete (va con su bandera).
        var sizes: [Int: Int] = [:]
        for e in events { if let g = e.beamGroup { sizes[g, default: 0] += 1 } }
        for i in events.indices where events[i].beamGroup.map({ sizes[$0] == 1 }) == true {
            events[i].beamGroup = nil
        }
        return Voice(clef: clef, events: events, slurs: [])
    }
}

extension Piece {
    /// Obras transcritas, por número del libro.
    static func number(_ n: Int) -> Piece? { library.first { $0.number == n } }

    /// Transcritas del PDF (Edition Peters). Cada compás escrito una vez (sin repeticiones).
    static let library: [Piece] = [
        Piece(number: 1, meter: .fourFour, keyFifths: 0, rightClef: .treble, leftClef: .treble,
              right: "C5/1 | D5/2 E5/2 | C5/1 | D5/2 E5/2 | C5/2 E5/2 | G5/2 F5/2 | E5/2 D5/2 | C5/1 | D5/2 E5/2 | F5/2 D5/2 | E5/2 F5/2 | G5/2 E5/2 | D5/2 E5/2 | F5/2 D5/2 | C5/2 E5/2 | C5/1",
              left: "C4/2 E4/2 | G4/1 | C4/2 E4/2 | G4/1 | C4/1 | E4/2 F4/2 | G4/2 F4/2 | E4/1 | G4/1 | G4/1 | C4/2 D4/2 | E4/2 C4/2 | G4/1 | G4/1 | E4/2 G4/2 | C4/1"),
        Piece(number: 2, meter: .fourFour, keyFifths: 0, rightClef: .treble, leftClef: .treble,
              right: "G5/2 C6/2 | B5/2 A5/2 | G5/2 G5/2 | G5/1 | B5/1 | B5/1 | C6/2 G5/2 | G5/1 | G5/2 C6/2 | B5/2 A5/2 | G5/2 G5/2 | G5/1 | B5/2 B5/2 | B5/2 B5/2 | C6/2 C6/2 | C6/1 | B5/2 C6/2 | D6/2 B5/2 | C6/2 G5/2 | G5/1 | B5/2 C6/2 | D6/2 B5/2 | C6/2 G5/2 | G5/1 | G5/2 C6/2 | B5/2 A5/2 | G5/2 G5/2 | G5/1 | B5/1 | B5/1 | C6/2 C6/2 | C6/1",
              left: "E4/2 C4/2 | F4/2 C4/2 | E4/2 C4/2 | E4/2 C4/2 | D4/2 G4/2 | F4/2 D4/2 | E4/2 G4/2 | E4/2 G4/2 | E4/2 C4/2 | F4/2 C4/2 | E4/2 C4/2 | E4/2 C4/2 | D4/2 G4/2 | F4/2 D4/2 | C4/2 E4/2 | C4/1 | G4/1 | G4/1 | C4/2 G4/2 | E4/2 C4/2 | G4/1 | G4/2 G4/2 | C4/2 E4/2 | G4/2 F4/2 | E4/2 C4/2 | F4/2 C4/2 | E4/2 C4/2 | E4/2 C4/2 | D4/2 G4/2 | F4/2 D4/2 | C4/2 E4/2 | C4/1"),
        Piece(number: 10, meter: .fourFour, keyFifths: 0, rightClef: .treble, leftClef: .treble,
              right: "E5+G5+C6/2 E5+G5+C6/2 | C5+E5+G5/2 C5+E5+G5/2 | D5+G5+B5/2 D5+G5+B5/2 | E5+G5+C6/1 | C5+F5+A5/2 C5+F5+A5/2 | C5+E5+G5/1 | B4+D5+F5/2 B4+D5+F5/2 | G4+C5+E5/1 | G4+B4+D5/2 G4+B4+D5/2 | G4+C5+E5/2 G4+C5+E5/2 | D5+F5/2 B4+D5/2 | C5/1",
              left: "C4+E4+G4/2 C4+E4+G4/2 | C4+E4+G4/2 C4+E4+G4/2 | G3+D4+F4/2 G3+D4+F4/2 | C4+E4+G4/1 | C4+F4+A4/2 C4+F4+A4/2 | C4+E4+G4/1 | G3+D4+F4/2 G3+D4+F4/2 | C4+E4/1 | G3+D4/2 G3+D4/2 | C4+E4/2 C4+E4/2 | G3+B3+D4/2 G3+D4+F4/2 | C4+E4/1"),
        Piece(number: 12, meter: .fourFour, keyFifths: 0, rightClef: .treble, leftClef: .treble,
              right: "C5/8 D5/8 E5/8 F5/8 G5/4 G5/4 | G5/8 F5/8 E5/8 D5/8 C5/4 E5/4 | D5/8 E5/8 F5/8 D5/8 G5/4 F5/4 | E5/8 F5/8 G5/8 E5/8 C5/2 | C5/8 D5/8 E5/8 D5/8 C5/8 D5/8 E5/8 F5/8 | G5/8 F5/8 E5/8 D5/8 C5/4 E5/4 | D5/8 E5/8 F5/8 E5/8 G5/8 F5/8 E5/8 D5/8 | C5/8 E5/8 G5/8 E5/8 C5/2 | D5/8 E5/8 F5/8 E5/8 G5/8 F5/8 E5/8 D5/8 | E5/8 F5/8 G5/8 E5/8 C5/4 C5/4 | D5/8 E5/8 F5/8 D5/8 G5/8 F5/8 E5/8 D5/8 | E5/8 F5/8 G5/8 E5/8 C5/4 C5/4 | C5/8 D5/8 E5/8 F5/8 G5/8 G5/8 G5/8 G5/8 | G5/8 F5/8 E5/8 D5/8 C5/8 D5/8 E5/8 C5/8 | D5/8 E5/8 F5/8 D5/8 G5/8 F5/8 E5/8 D5/8 | C5/8 E5/8 G5/8 E5/8 C5/2",
              left: "C4+E4+G4/1 | C4+E4+G4/1 | B3+D4+G4/1 | C4+E4+G4/1 | C4+E4+G4/1 | C4+E4+G4/1 | B3+F4+G4/1 | C4+E4+G4/1 | B3+D4+G4/1 | C4+E4+G4/1 | B3+D4+G4/1 | C4+E4+G4/1 | C4+E4+G4/1 | C4+E4+G4/1 | B3+F4+G4/2 B3+F4+G4/2 | C4+E4+G4/1"),
        Piece(number: 18, meter: .fourFour, keyFifths: 0, rightClef: .treble, leftClef: .treble,
              right: "C5/16 E5/16 D5/16 C5/16 D5/16 F5/16 E5/16 D5/16 E5/16 G5/16 F5/16 E5/16 D5/16 F5/16 E5/16 D5/16 | C5/16 E5/16 D5/16 C5/16 D5/16 F5/16 E5/16 D5/16 E5/16 G5/16 F5/16 E5/16 C5/16 E5/16 D5/16 C5/16 | D5/16 G5/16 D5/16 G5/16 E5/16 G5/16 E5/16 G5/16 F5/16 G5/16 F5/16 G5/16 D5/16 G5/16 D5/16 G5/16 | E5/16 G5/16 E5/16 G5/16 E5/16 G5/16 E5/16 G5/16 C5/16 G5/16 C5/16 G5/16 C5/16 G5/16 C5/16 G5/16 | C5/16 E5/16 D5/16 C5/16 D5/16 F5/16 E5/16 D5/16 E5/16 G5/16 F5/16 E5/16 D5/16 F5/16 E5/16 D5/16 | C5/16 E5/16 D5/16 C5/16 D5/16 F5/16 E5/16 D5/16 E5/16 G5/16 F5/16 E5/16 C5/16 E5/16 D5/16 C5/16 | D5/16 G5/16 D5/16 G5/16 E5/16 G5/16 E5/16 G5/16 F5/16 G5/16 F5/16 G5/16 D5/16 G5/16 D5/16 G5/16 | C5/16 E5/16 G5/16 E5/16 C5/16 E5/16 G5/16 E5/16 C5/2 | G5/16 F5/16 E5/16 D5/16 G5/16 F5/16 E5/16 D5/16 G5/16 F5/16 E5/16 D5/16 G5/16 F5/16 E5/16 D5/16 | E5/16 F5/16 E5/16 D5/16 C5/16 D5/16 E5/16 F5/16 G5/16 C5/16 E5/16 C5/16 G5/16 C5/16 E5/16 C5/16 | G5/16 F5/16 E5/16 D5/16 G5/16 F5/16 E5/16 D5/16 G5/16 F5/16 E5/16 D5/16 G5/16 F5/16 E5/16 D5/16 | E5/16 F5/16 E5/16 D5/16 C5/16 D5/16 E5/16 F5/16 G5/16 C5/16 E5/16 C5/16 G5/16 C5/16 E5/16 C5/16 | E5/16 G5/16 F5/16 E5/16 D5/16 F5/16 E5/16 D5/16 C5/16 E5/16 D5/16 C5/16 D5/16 F5/16 E5/16 D5/16 | E5/16 G5/16 F5/16 E5/16 D5/16 F5/16 E5/16 D5/16 C5/16 E5/16 D5/16 C5/16 E5/16 G5/16 F5/16 E5/16 | D5/16 G5/16 E5/16 G5/16 F5/16 G5/16 E5/16 G5/16 D5/16 G5/16 F5/16 G5/16 E5/16 G5/16 D5/16 G5/16 | C5/16 G5/16 E5/16 G5/16 C5/16 G5/16 E5/16 G5/16 C5/2",
              left: "C4+E4+G4/4 B3+D4+G4/4 C4+E4+G4/4 B3+D4+G4/4 | C4+E4+G4/4 B3+D4+G4/4 C4+E4+G4/2 | B3+G4/4 C4+G4/4 D4+G4/4 B3+G4/4 | C4+G4/2 E4+G4/2 | C4+E4+G4/4 B3+D4+G4/4 C4+E4+G4/4 B3+D4+G4/4 | C4+E4+G4/4 B3+D4+G4/4 C4+E4+G4/2 | B3+G4/4 C4+G4/4 D4+G4/4 B3+G4/4 | C4+E4+G4/1 | B3+D4+G4/2 B3+D4+G4/2 | C4+E4+G4/1 | B3+D4+G4/2 B3+D4+G4/2 | C4+E4+G4/1 | C4+E4+G4/4 B3+D4+G4/4 C4+E4+G4/4 B3+D4+G4/4 | C4+E4+G4/4 B3+D4+G4/4 C4+E4+G4/2 | B3+F4+G4/2 B3+F4+G4/2 | C4+E4+G4/1"),
        Piece(number: 21, meter: .threeFour, keyFifths: 0, rightClef: .treble, leftClef: .treble,
              right: "E5+G5/2 D5+F5/4 | C5+E5/2. | A5+C6/2 G5+B5/4 | F5+A5/2. | E5+G5/2 E5+G5/4 | E5+G5/4 D5+F5/4 C5+E5/4 | D5/4 D5/4 D5/4 | D5/2. | E5+G5/2 D5+F5/4 | C5+E5/2. | A5+C6/2 G5+B5/4 | F5+A5/2. | E5+G5/2 E5/4 | G5/4 F5/4 D5/4 | C5/4 C5/4 C5/4 | C5/2. | D5+F5/2 D5+F5/4 | D5+F5/4 E5+G5/4 D5+F5/4 | C5+E5/2 G5/4 | E5/4 C6/4 G5/4 | E5+G5/4 D5+F5/4 D5+F5/4 | D5+F5/4 E5+G5/4 D5+F5/4 | C5+E5/2 G5/4 | E5/4 C6/4 C6/4 | A5+C6/2 A5+C6/4 | A5+C6/4 G5+B5/4 F5+A5/4 | E5+G5/2 E5+G5/4 | E5+G5/4 D5+F5/4 C5+E5/4 | D5/4 D5/4 D5/4 | G5/4 F5/4 D5/4 | C5/4 C5/4 E5/4 | C5/2.",
              left: "C4/4 E4+G4/4 E4+G4/4 | C4/4 E4+G4/4 E4+G4/4 | C4/4 F4+A4/4 F4+A4/4 | C4/4 F4+A4/4 F4+A4/4 | C4/4 E4+G4/4 E4+G4/4 | C4/4 E4+G4/4 E4+G4/4 | G3/4 B3+D4/4 B3+D4/4 | G3/4 B3+D4/4 B3+D4/4 | C4/4 E4+G4/4 E4+G4/4 | C4/4 E4+G4/4 E4+G4/4 | C4/4 F4+A4/4 F4+A4/4 | C4/4 F4+A4/4 F4+A4/4 | C4/4 E4+G4/4 E4+G4/4 | G3/4 B3+F4/4 B3+F4/4 | C4/4 E4+G4/4 E4+G4/4 | C4/4 E4+G4/4 E4+G4/4 | B3/4 D4+G4/4 D4+G4/4 | B3/4 D4+G4/4 D4+G4/4 | C4/4 E4+G4/4 E4+G4/4 | C4/4 E4+G4/4 E4+G4/4 | B3/4 D4+G4/4 D4+G4/4 | B3/4 D4+G4/4 D4+G4/4 | C4/4 E4+G4/4 E4+G4/4 | C4/4 E4+G4/4 E4+G4/4 | C4/4 F4+A4/4 F4+A4/4 | C4/4 F4+A4/4 F4+A4/4 | C4/4 E4+G4/4 E4+G4/4 | C4/4 E4+G4/4 E4+G4/4 | G3/4 B3+F4/4 B3+F4/4 | G3/4 B3+F4/4 B3+F4/4 | C4/4 E4+G4/4 E4+G4/4 | C4+E4+G4/2."),
        Piece(number: 28, meter: .fourFour, keyFifths: 0, rightClef: .treble, leftClef: .treble,
              right: "G5/4 E6/8 C6/8 G5/4 G5/4 | G5/4 E6/8 C6/8 G5/4 G5/4 | F5/4 D6/4 E5/4 C6/4 | D5/4 B5/4 E5+C6/2 | G5/4 B5/8 D6/8 F6/4 F6/4 | E6/4 G6/4 C6/2 | G5/4 B5/8 D6/8 F6/4 F6/4 | E6/4 G6/4 C6/2 | G5/4 E6/8 C6/8 G5/4 G5/4 | G5/4 E6/8 C6/8 G5/4 G5/4 | F5/4 D6/4 E5/4 C6/4 | D5/4 B5/4 E5+C6/2",
              left: "C4/8 G4/8 E4/8 G4/8 C4/8 G4/8 E4/8 G4/8 | C4/8 G4/8 E4/8 G4/8 C4/8 G4/8 E4/8 G4/8 | B3/8 G4/8 D4/8 G4/8 C4/8 G4/8 E4/8 G4/8 | G3/8 F4/8 D4/8 F4/8 C4/8 G4/8 E4/8 G4/8 | B3/8 G4/8 D4/8 G4/8 B3/8 G4/8 D4/8 G4/8 | C4/8 G4/8 E4/8 G4/8 C4/8 G4/8 E4/8 G4/8 | B3/8 G4/8 D4/8 G4/8 B3/8 G4/8 D4/8 G4/8 | C4/8 G4/8 E4/8 G4/8 C4/8 G4/8 E4/8 G4/8 | C4/8 G4/8 E4/8 G4/8 C4/8 G4/8 E4/8 G4/8 | C4/8 G4/8 E4/8 G4/8 C4/8 G4/8 E4/8 G4/8 | B3/8 G4/8 D4/8 G4/8 C4/8 G4/8 E4/8 G4/8 | G3/8 F4/8 D4/8 F4/8 C4+E4/2"),
        Piece(number: 32, meter: .fourFour, keyFifths: 0, rightClef: .treble, leftClef: .bass,
              right: "E4+G4+C5/4 E4+G4+C5/4 E4+G4+C5/4 E4+G4+C5/4 | E4+G4+C5/1 | G4+B4+D5/4 G4+B4+D5/4 G4+B4+D5/4 G4+B4+D5/4 | G4+B4+D5/1 | G4+C5+E5/4 G4+C5+E5/4 G4+C5+E5/4 G4+C5+E5/4 | G4+C5+E5/1 | E5+G5/4 D5+F5/4 G4+C5+E5/4 F4+B4+D5/4 | E4+C5/4 E4+C5/4 E4+C5/2 | G4+D5+F5/4 G4+D5+F5/4 G4+D5+F5/4 G4+D5+F5/4 | G4+C5+E5/1 | F4+G4+D5/4 F4+G4+D5/4 F4+G4+D5/4 F4+G4+D5/4 | E4+G4+C5/1 | F5+A5/4 F5+A5/4 F5+A5/4 F5+A5/4 | E5+G5/2 A4+D5+F5/4 A4+D5+F5/4 | G4+C5+E5/4 G4+C5+E5/4 F4+B4+D5/4 F4+B4+D5/4 | E4+C5/1",
              left: "C3/4 E3/4 G3/4 E3/4 | C3/4 G3/4 E3/4 C3/4 | G2/4 B2/4 D3/4 B2/4 | G2/4 B2/4 D3/4 G3/4 | C3/4 E3/4 G3/4 E3/4 | C3/4 E3/4 G3/4 C4/4 | G3/4 G3/4 G3/4 G3/4 | C4/4 G3/4 C3/2 | G2/4 A2/4 B2/4 G2/4 | C3/4 G2/4 C3/4 E3/4 | G3/4 D3/4 B2/4 G2/4 | C3/4 G3/4 E3/4 C3/4 | F2/4 G2/4 A2/4 B2/4 | C3/4 C3/4 F2/4 F3/4 | G2/4 G3/4 G2/4 G3/4 | C3/4 C4/4 C3/2"),
        Piece(number: 36, meter: .fourFour, keyFifths: 0, rightClef: .treble, leftClef: .bass,
              right: "F#5/8 G5/8 A5/8 G5/8 F5/4 E5/4 | D#5/8 E5/8 F5/8 E5/8 D5/4 C5/4 | C#5/4 D5/4 C#5/4 D5/4 | D#5/4 E5/4 E5/2 | A5/8 G5/8 F#5/8 G5/8 C6/4 G5/4 | F5/8 E5/8 D#5/8 E5/8 G5/4 E5/4 | D5/4 B5/4 A5/4 F#5/4 | A5/4 G5/4 G5/2 | F5/2 C#5/8 D5/8 G5/8 F5/8 | E5/4 C6/4 G5/2 | G5/8 F5/8 E5/8 F5/8 C#5/8 D5/8 G5/8 F5/8 | E5/4 C6/4 G5/2 | Bb5/4 Bb5/4 Bb5/4 Bb5/4 | A5/4 C6/4 B5/8 C6/8 A5/8 F5/8 | E5/4 G5/4 F#5/8 G5/8 F5/8 D5/8 | D5/4 C5/4 C5/2",
              left: "C3/8 G3/8 E3/8 G3/8 C3/8 G3/8 E3/8 G3/8 | C3/8 G3/8 E3/8 G3/8 C3/8 G3/8 E3/8 G3/8 | B2/8 G3/8 F3/8 G3/8 B2/8 G3/8 F3/8 G3/8 | C3/8 G3/8 E3/8 G3/8 C3/8 G3/8 E3/8 G3/8 | C3/8 G3/8 E3/8 G3/8 C3/8 G3/8 E3/8 G3/8 | C3/8 G3/8 E3/8 G3/8 C3/8 G3/8 C3/8 G3/8 | D3/8 B3/8 G3/8 B3/8 D3/8 C4/8 A3/8 C4/8 | G3/8 D4/8 B3/8 D4/8 G3/2 | G3/8 D4/8 B3/8 D4/8 G3/8 D4/8 B3/8 D4/8 | G3/8 E4/8 C4/8 E4/8 G3/8 E4/8 C4/8 E4/8 | G3/8 D4/8 B3/8 D4/8 G3/8 D4/8 B3/8 D4/8 | C3/8 G3/8 E3/8 G3/8 C3/8 G3/8 E3/8 G3/8 | E3/8 C4/8 G3/8 C4/8 E3/8 C4/8 G3/8 C4/8 | F3/8 C4/8 A3/8 C4/8 F3/8 C4/8 A3/8 C4/8 | G3/8 E4/8 C4/8 E4/8 G3/8 F4/8 B3/8 F4/8 | C4/8 G4/8 E4/8 G4/8 C4/2"),
        Piece(number: 39, meter: .fourFour, keyFifths: 1, rightClef: .treble, leftClef: .bass,
              right: "G5/4 G5/4 F#5/4 F#5/4 | G5/4 G5/4 A5/4 A5/4 | B5/8 D6/8 C6/8 B5/8 A5/8 G5/8 F#5/8 G5/8 | A5/8 B5/8 A5/8 F#5/8 D5/2 | G5/4 G5/4 F#5/4 F#5/4 | G5/4 G5/4 A5/4 A5/4 | B5/8 D6/8 B5/8 G5/8 F#5/8 C6/8 A5/8 F#5/8 | G5/4 G5/4 G5/2 | G5/4 G5/4 G5/8 F#5/8 G5/8 A5/8 | F#5/4 A5/4 D6/2 | C#6/4 C#6/4 C#6/8 A5/8 B5/8 C#6/8 | D6/1 | C6/4 C6/4 C6/8 E6/8 D6/8 C6/8 | B5/8 D6/8 C6/8 B5/8 A5/8 C6/8 B5/8 A5/8 | G5/8 B5/8 A5/8 G5/8 F#5/8 A5/8 G5/8 F#5/8 | G5/4 G5/4 G5/2",
              left: "G3/8 D4/8 B3/8 D4/8 A3/8 D4/8 C4/8 D4/8 | G3/8 D4/8 B3/8 D4/8 F#3/8 D4/8 A3/8 D4/8 | G3/8 D4/8 B3/8 D4/8 G3/8 D4/8 B3/8 D4/8 | D3/8 A3/8 F#3/8 A3/8 D3/8 A3/8 F#3/8 A3/8 | G3/8 D4/8 B3/8 D4/8 A3/8 D4/8 C4/8 D4/8 | G3/8 D4/8 B3/8 D4/8 F#3/8 D4/8 A3/8 D4/8 | G3/8 D4/8 B3/8 D4/8 D3/8 C4/8 A3/8 C4/8 | G3/8 D4/8 B3/8 D4/8 G3/2 | C#3/8 A3/8 E3/8 A3/8 C#3/8 A3/8 E3/8 A3/8 | D3/8 A3/8 F#3/8 A3/8 D3/8 A3/8 F#3/8 A3/8 | E3/8 A3/8 G3/8 A3/8 E3/8 A3/8 G3/8 A3/8 | D3/8 A3/8 F#3/8 A3/8 D3/8 A3/8 F#3/8 A3/8 | F#3/8 D4/8 A3/8 D4/8 F#3/8 D4/8 A3/8 D4/8 | G3/8 D4/8 B3/8 D4/8 C3/8 A3/8 E3/8 A3/8 | D3/8 B3/8 G3/8 B3/8 D3/8 C4/8 A3/8 C4/8 | G3/8 D4/8 B3/8 D4/8 G3/2"),
        Piece(number: 47, meter: .threeFour, keyFifths: -1, rightClef: .treble, leftClef: .bass,
              right: "C5/4. F5/8 A5/8 F5/8 | C5/4. A4/8 F4/8 D5/8 | C5/4. Bb4/8 G4/8 D5/8 | C5/2 A4/4 | C5/4. F5/8 A5/8 F5/8 | E5/4. G5/8 E6/8 C6/8 | B5/8 F6/8 D6/8 B5/8 G5/8 B5/8 | C6/4 r/4 r/4 | C5/8 Bb5/8 G5/4. C5/8 | C5/8 A5/8 F5/4. C5/8 | C5/8 E5/8 G5/8 Bb5/8 D6/8 C6/8 | C6/2 A5/4 | C5/8 Bb5/8 G5/4. C5/8 | C5/8 A5/8 F5/4. C6/8 | C6/8 Bb5/8 G5/8 E5/8 C5/8 E5/8 | F5/4 r/4 r/4",
              left: "F3/4 A3+C4/4 A3+C4/4 | F3/4 A3+C4/4 A3+C4/4 | E3/4 G3+C4/4 G3+C4/4 | F3/4 A3+C4/4 A3+C4/4 | F3/4 A3+C4/4 A3+C4/4 | G3/4 C4+E4/4 C4+E4/4 | G3/4 D4+F4/4 D4+F4/4 | C4+E4/4 C4+E4/4 C4+E4/4 | E3/4 G3+C4/4 G3+C4/4 | F3/4 A3+C4/4 A3+C4/4 | C3/4 E3+G3+Bb3/4 E3+G3+Bb3/4 | F3/4 A3+C4/4 A3+C4/4 | E3/4 G3+C4/4 G3+C4/4 | F3/4 A3+C4/4 A3+C4/4 | C3/4 G3+Bb3/4 G3+Bb3/4 | F3+A3/4 F3+A3/4 F3+A3/4"),
        Piece(number: 94, meter: .twoFour, keyFifths: 4, rightClef: .treble, leftClef: .bass,
              right: "B4/16 E5/16 G#5/16 B5/16 E6/16 G#6/16 B6/16 A6/16 | G#6/16 F#6/16 E6/16 D#6/16 C#6/16 B5/16 A5/16 G#5/16 | F#5/16 E5/16 D#5/16 C#5/16 B4/16 A4/16 G#4/16 F#4/16 | G#4/8 E4/8 B4/8 r/8 | B4/16 E5/16 G#5/16 B5/16 E6/16 G#6/16 B6/16 A6/16 | G#6/16 F#6/16 E6/16 D#6/16 C#6/16 B5/16 A5/16 G#5/16 | F#5/16 E5/16 D#5/16 C#5/16 B4/16 A4/16 G#4/16 F#4/16 | E4/8 G#4/8 E4/8 r/8 | B3/16 D#4/16 F#4/16 B4/16 D#5/16 F#5/16 D#5/16 B4/16 | G#5/16 E5/16 B5/16 G#5/16 E5/16 B4/16 G#4/16 E4/16 | B3/16 D#4/16 F#4/16 B4/16 D#5/16 F#5/16 D#5/16 B4/16 | G#5/16 E5/16 B5/16 G#5/16 E5/16 B4/16 G#4/16 E4/16 | B3/16 C#4/16 D#4/16 E4/16 F#4/16 G#4/16 A4/16 B4/16 | C#5/16 D#5/16 E5/16 F#5/16 G#5/16 A5/16 B5/16 C#6/16 | D#6/16 E6/16 F#6/16 G#6/16 A6/16 B6/16 C#7/16 D#7/16 | E7/16 B6/16 G#6/16 B6/16 E6/8 r/8",
              left: "E3+G#3+B3/8 E3+G#3+B3/8 E3+G#3+B3/8 E3+G#3+B3/8 | E3+G#3+B3/8 E3+G#3+B3/8 E3+G#3+B3/8 E3+G#3+B3/8 | B2+D#3+A3/8 B2+D#3+A3/8 B2+D#3+A3/8 B2+D#3+A3/8 | E3+G#3+B3/8 E3+G#3+B3/8 E3+G#3+B3/8 E3+G#3+B3/8 | E3+G#3+B3/8 E3+G#3+B3/8 E3+G#3+B3/8 E3+G#3+B3/8 | E3+G#3+B3/8 E3+G#3+B3/8 E3+G#3+B3/8 E3+G#3+B3/8 | B2+D#3+A3/8 B2+D#3+A3/8 B2+D#3+A3/8 B2+D#3+A3/8 | E3+G#3/8 E3+G#3/8 E3+G#3/8 E3+G#3/8 | D#3+F#3+A3/8 B2/8 D#3+F#3+A3/8 B2/8 | E3+G#3/8 B2/8 E3+G#3/8 B2/8 | D#3+F#3+A3/8 B2/8 D#3+F#3+A3/8 B2/8 | E3+G#3/8 B2/8 E3+G#3/8 B2/8 | E3+G#3/8 E3+G#3/8 E3+G#3/8 E3+G#3/8 | E3+G#3/8 E3+G#3/8 E3+G#3/8 E3+G#3/8 | B2+F#3+A3/8 B2+F#3+A3/8 B2+F#3+A3/8 B2+F#3+A3/8 | E3+G#3/8 E3+G#3/8 E3+G#3/8 r/8"),
    ]
}
