import Foundation

/// Un ejercicio = pasos en orden; cada paso son las notas que se tocan juntas.
/// Nota: 1 paso de 1 nota. Dos notas / tríada: 1 paso de 2–3 notas. Progresión: 2–5 pasos de 1 nota.
struct Exercise: Identifiable {
    let id = UUID()
    let clef: Clef
    let kind: ExerciseKind
    let steps: [[Note]]

    func label(_ style: NamingStyle, octave: Bool) -> String {
        steps
            .map { $0.map { $0.name(style, octave: octave) }.joined(separator: "-") }
            .joined(separator: " → ")
    }

    var signature: String {
        clef.rawValue + steps.map { $0.map { "\($0.diatonic)\($0.accidental.rawValue)" }.joined(separator: ",") }.joined(separator: "|")
    }
}

struct ExerciseGenerator {
    let settings: PracticeSettings

    func next(after previous: Exercise?) -> Exercise {
        for _ in 0..<12 {
            let exercise = make()
            if exercise.signature != previous?.signature { return exercise }
        }
        return make()
    }

    private func make() -> Exercise {
        let kind = settings.kinds.randomElement() ?? .single
        let clef = settings.clef.pick()
        let range = clef.range(ledgerLines: settings.ledgerLines)

        switch kind {
        case .single:
            return Exercise(clef: clef, kind: kind, steps: [[randomNote(in: range)]])

        case .interval:
            let size = Int.random(in: 1...min(6, range.count - 1))
            let low = Int.random(in: range.lowerBound...(range.upperBound - size))
            return Exercise(clef: clef, kind: kind, steps: [[Note(diatonic: low), Note(diatonic: low + size)]])

        case .triad:
            let root = Int.random(in: range.lowerBound...(range.upperBound - 4))
            return Exercise(clef: clef, kind: kind, steps: [[root, root + 2, root + 4].map { Note(diatonic: $0) }])

        case .progression:
            let count = min(max(settings.progressionLength, 2), 5)
            var notes: [Note] = []
            while notes.count < count {
                let note = randomNote(in: range)
                if note != notes.last { notes.append(note) }
            }
            return Exercise(clef: clef, kind: kind, steps: notes.map { [$0] })
        }
    }

    private func randomNote(in range: ClosedRange<Int>) -> Note {
        let diatonic = Int.random(in: range)
        guard settings.accidentals else { return Note(diatonic: diatonic) }
        let letter = Letter(rawValue: diatonic % 7)!
        var options: [Accidental] = [.natural]
        if letter != .e && letter != .b { options.append(.sharp) }
        if letter != .c && letter != .f { options.append(.flat) }
        return Note(diatonic: diatonic, accidental: options.randomElement()!)
    }
}
