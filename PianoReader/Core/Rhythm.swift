import Foundation

enum PracticeMode: String, CaseIterable, Identifiable, Codable {
    case notes, rhythm
    var id: String { rawValue }
    var label: String { self == .notes ? "Notas" : "Ritmo" }
}

enum RhythmFeature: String, CaseIterable, Identifiable, Codable {
    case long, eighths, sixteenths, dotted, saltillo, triplets, rests, ties, slurs
    var id: String { rawValue }

    var label: String {
        switch self {
        case .long: "Blancas y redondas"
        case .eighths: "Corcheas"
        case .sixteenths: "Semicorcheas"
        case .dotted: "Puntillo"
        case .saltillo: "Saltillo"
        case .triplets: "Tresillos"
        case .rests: "Silencios"
        case .ties: "Ligaduras de prolongación"
        case .slurs: "Ligaduras de expresión (legato)"
        }
    }
}

/// Duración en ticks: negra = 48 (divisible para tresillos y semicorcheas).
enum NoteValue: Int {
    case whole = 192, half = 96, quarter = 48, eighth = 24, sixteenth = 12

    var beams: Int {
        switch self {
        case .eighth: 1
        case .sixteenth: 2
        default: 0
        }
    }

    var hasStem: Bool { self != .whole }
}

struct CellItem {
    let value: NoteValue
    var dotted = false
    var triplet = false
    var rest = false

    var ticks: Int {
        var t = value.rawValue
        if dotted { t = t * 3 / 2 }
        if triplet { t = t * 2 / 3 }
        return t
    }
}

/// Célula rítmica que llena uno o más tiempos.
struct RhythmCell {
    let items: [CellItem]
    let requires: Set<RhythmFeature>

    var ticks: Int { items.reduce(0) { $0 + $1.ticks } }
    var hasRest: Bool { items.contains { $0.rest } }

    static func library(for meter: Meter) -> [RhythmCell] {
        func n(_ v: NoteValue, dot: Bool = false, tri: Bool = false) -> CellItem {
            CellItem(value: v, dotted: dot, triplet: tri)
        }
        func r(_ v: NoteValue) -> CellItem { CellItem(value: v, rest: true) }

        if meter == .sixEight {
            return [
                RhythmCell(items: [n(.quarter, dot: true)], requires: []),
                RhythmCell(items: [n(.quarter), n(.eighth)], requires: [.eighths]),
                RhythmCell(items: [n(.eighth), n(.quarter)], requires: [.eighths]),
                RhythmCell(items: [n(.eighth), n(.eighth), n(.eighth)], requires: [.eighths]),
                RhythmCell(items: [r(.eighth), n(.eighth), n(.eighth)], requires: [.eighths, .rests]),
                RhythmCell(items: [r(.quarter), n(.eighth)], requires: [.eighths, .rests]),
                RhythmCell(items: [n(.eighth, dot: true), n(.sixteenth), n(.eighth)], requires: [.saltillo]),
                RhythmCell(items: [n(.sixteenth), n(.sixteenth), n(.eighth), n(.eighth)], requires: [.sixteenths]),
                RhythmCell(items: [n(.eighth), n(.eighth), n(.sixteenth), n(.sixteenth)], requires: [.sixteenths]),
                RhythmCell(items: [n(.half, dot: true)], requires: [.long]),
            ]
        }

        var cells = [
            RhythmCell(items: [n(.quarter)], requires: []),
            RhythmCell(items: [r(.quarter)], requires: [.rests]),
            RhythmCell(items: [n(.eighth), n(.eighth)], requires: [.eighths]),
            RhythmCell(items: [r(.eighth), n(.eighth)], requires: [.eighths, .rests]),
            RhythmCell(items: [n(.eighth), r(.eighth)], requires: [.eighths, .rests]),
            RhythmCell(items: [n(.sixteenth), n(.sixteenth), n(.sixteenth), n(.sixteenth)], requires: [.sixteenths]),
            RhythmCell(items: [n(.eighth), n(.sixteenth), n(.sixteenth)], requires: [.eighths, .sixteenths]),
            RhythmCell(items: [n(.sixteenth), n(.sixteenth), n(.eighth)], requires: [.eighths, .sixteenths]),
            RhythmCell(items: [n(.eighth, dot: true), n(.sixteenth)], requires: [.saltillo]),
            RhythmCell(items: [n(.eighth, tri: true), n(.eighth, tri: true), n(.eighth, tri: true)], requires: [.triplets]),
            RhythmCell(items: [n(.half)], requires: [.long]),
            RhythmCell(items: [r(.half)], requires: [.long, .rests]),
            RhythmCell(items: [n(.quarter, dot: true), n(.eighth)], requires: [.dotted]),
        ]
        if meter != .twoFour {
            cells.append(RhythmCell(items: [n(.half, dot: true)], requires: [.long, .dotted]))
        }
        if meter == .fourFour {
            cells.append(RhythmCell(items: [n(.whole)], requires: [.long]))
            cells.append(RhythmCell(items: [r(.whole)], requires: [.long, .rests]))
        }
        return cells
    }
}

struct RhythmEvent {
    /// Inicio en ticks desde el comienzo del ejercicio.
    let tick: Int
    let item: CellItem
    let measure: Int
    let cellStart: Bool
    var note: Note?
    var beamGroup: Int?
    var tupletGroup: Int?
    var tiedToNext = false
    var tiedFromPrevious = false

    var isRest: Bool { item.rest }
}

struct RhythmExercise: Identifiable {
    let id = UUID()
    let clef: Clef
    let meter: Meter
    let measures: Int
    let events: [RhythmEvent]
    /// Rangos de índices de eventos bajo una ligadura de expresión.
    let slurs: [ClosedRange<Int>]

    var totalTicks: Int { meter.measureTicks * measures }

    func label(_ style: NamingStyle) -> String {
        events.filter { !$0.isRest && !$0.tiedFromPrevious }
            .compactMap { $0.note?.name(style, octave: false) }
            .joined(separator: " ")
    }
}

struct RhythmGenerator {
    let settings: PracticeSettings

    func make() -> RhythmExercise {
        for _ in 0..<20 {
            let exercise = build()
            if exercise.events.filter({ !$0.isRest && !$0.tiedFromPrevious }).count >= 2 { return exercise }
        }
        return build()
    }

    private func build() -> RhythmExercise {
        let meter = settings.meter
        let features = settings.rhythmFeatures
        let clef = settings.clef.pick()
        let library = RhythmCell.library(for: meter).filter { $0.requires.isSubset(of: features) }
        let beat = meter == .sixEight ? 72 : 48
        let measures = min(max(settings.rhythmMeasures, 1), 2)

        var events: [RhythmEvent] = []
        var groupId = 0

        for measure in 0..<measures {
            var pos = 0
            while pos < meter.measureTicks {
                let fits = library.filter { cell in
                    guard pos + cell.ticks <= meter.measureTicks else { return false }
                    if meter == .fourFour && cell.ticks == 2 * beat { return pos % (2 * beat) == 0 }
                    return true
                }
                let pool = fits.flatMap { Array(repeating: $0, count: $0.hasRest ? 1 : 2) }
                let cell = pool.randomElement() ?? RhythmCell(items: [CellItem(value: .quarter)], requires: [])

                var run: [Int] = []
                func flushBeams() {
                    if run.count >= 2 {
                        for i in run { events[i].beamGroup = groupId }
                        groupId += 1
                    }
                    run = []
                }
                let tuplet: Int? = cell.items.first?.triplet == true ? groupId : nil
                if tuplet != nil { groupId += 1 }

                var tick = pos
                for (k, item) in cell.items.enumerated() {
                    events.append(RhythmEvent(tick: measure * meter.measureTicks + tick, item: item,
                                              measure: measure, cellStart: k == 0, tupletGroup: tuplet))
                    if !item.rest && item.value.beams > 0 {
                        run.append(events.count - 1)
                    } else {
                        flushBeams()
                    }
                    tick += item.ticks
                }
                flushBeams()
                pos += cell.ticks
            }
        }

        // Alturas: paso a paso (más fácil de leer), sin repetir la misma nota seguida.
        let range = clef.range(ledgerLines: settings.ledgerLines)
        var current = (range.lowerBound + range.upperBound) / 2 + Int.random(in: -2...2)
        for i in events.indices where !events[i].isRest {
            var next = current
            for _ in 0..<20 {
                let candidate = current + Int.random(in: -3...3)
                if candidate != current && range.contains(candidate) { next = candidate; break }
            }
            current = next
            events[i].note = Note(diatonic: current)
        }

        // Ligaduras de prolongación: entre células (cruzando tiempos o la barra).
        if features.contains(.ties) {
            var count = 0
            for i in events.indices.dropLast() where count < 2 {
                let a = events[i], b = events[i + 1]
                guard !a.isRest, !b.isRest, b.cellStart, !a.tiedFromPrevious, Double.random(in: 0..<1) < 0.5 else { continue }
                events[i].tiedToNext = true
                events[i + 1].tiedFromPrevious = true
                events[i + 1].note = a.note
                count += 1
            }
        }

        // Ligaduras de expresión: 2–4 notas seguidas, sin silencios ni ligaduras de prolongación.
        var slurs: [ClosedRange<Int>] = []
        if features.contains(.slurs) {
            for measure in 0..<measures {
                let indices = events.indices.filter { events[$0].measure == measure }
                guard let first = indices.first, let last = indices.last else { continue }
                for _ in 0..<20 {
                    let length = Int.random(in: 2...4)
                    let start = Int.random(in: first...last)
                    let end = start + length - 1
                    guard end <= last else { continue }
                    let ok = (start...end).allSatisfy { !events[$0].isRest && !events[$0].tiedToNext && !events[$0].tiedFromPrevious }
                    if ok { slurs.append(start...end); break }
                }
            }
        }

        return RhythmExercise(clef: clef, meter: meter, measures: measures, events: events, slurs: slurs)
    }
}
