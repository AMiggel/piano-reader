import Foundation

/// Un ejercicio = pasos en orden; cada paso son las notas que se tocan juntas.
/// Nota: 1 paso de 1 nota. Dos notas / tríada: 1 paso de 2–3 notas. Progresión: 2–5 pasos de 1 nota.
struct Exercise: Identifiable {
    let id = UUID()
    let clef: Clef
    let key: KeySignature
    let kind: ExerciseKind
    let steps: [[Note]]

    /// Signos a escribir, con la misma forma que `steps`.
    var displayedAccidentals: [[Accidental?]] {
        var flat = key.displayed(steps.flatMap { $0 })
        return steps.map { step in
            let part = Array(flat.prefix(step.count))
            flat.removeFirst(step.count)
            return part
        }
    }

    func label(_ style: NamingStyle, octave: Bool) -> String {
        steps
            .map { $0.map { $0.name(style, octave: octave) }.joined(separator: "-") }
            .joined(separator: " → ")
    }

    var signature: String {
        clef.rawValue + "\(key.fifths)" + steps.map { $0.map { "\($0.diatonic)\($0.accidental.rawValue)" }.joined(separator: ",") }.joined(separator: "|")
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
        let key = settings.pickKey()
        let range = clef.range(ledgerLines: settings.ledgerLines)

        func build(_ steps: [[Note]]) -> Exercise {
            Exercise(clef: clef, key: key, kind: kind, steps: steps)
        }

        switch kind {
        case .single:
            return build([[randomNote(in: range, key: key)]])

        case .interval:
            let size = Int.random(in: 1...min(6, range.count - 1))
            let low = Int.random(in: range.lowerBound...(range.upperBound - size))
            return build([[key.note(low), key.note(low + size)]])

        case .triad:
            let root = Int.random(in: range.lowerBound...(range.upperBound - 4))
            return build([[root, root + 2, root + 4].map { key.note($0) }])

        case .progression:
            let count = min(max(settings.progressionLength, 2), 5)
            var notes: [Note] = []
            while notes.count < count {
                let note = randomNote(in: range, key: key)
                if note != notes.last { notes.append(note) }
            }
            return build(notes.map { [$0] })
        }
    }

    /// Nota de la tonalidad; con "Sostenidos y bemoles", a veces alterada (♯ ♭ ♮).
    private func randomNote(in range: ClosedRange<Int>, key: KeySignature) -> Note {
        let diatonic = Int.random(in: range)
        if settings.accidentals && Double.random(in: 0..<1) < 0.4 {
            return key.altered(diatonic)
        }
        return key.note(diatonic)
    }
}
