import Foundation

/// Movimiento de la mano en la melodía, siguiendo el orden de Czerny Op. 599:
/// primero cinco dedos quietos (Nos. 1–18), luego el paso del pulgar dentro de una octava (19–26)
/// y después más de una octava con saltos (27 en adelante).
enum HandMotion: String, CaseIterable, Identifiable, Codable {
    case fixed, octave, free
    var id: String { rawValue }

    var label: String {
        switch self {
        case .fixed: "5 dedos"
        case .octave: "Octava"
        case .free: "Libre"
        }
    }

    var detail: String {
        switch self {
        case .fixed: "Posición fija de cinco notas, sin mover la mano"
        case .octave: "Escalas dentro de una octava (paso del pulgar)"
        case .free: "Más de una octava, con saltos"
        }
    }
}

/// Acorde sobre un grado de la escala (0 = I, 1 = ii, 3 = IV, 4 = V, 5 = vi).
struct Harmony {
    let degree: Int
    var seventh = false

    static let I = Harmony(degree: 0)
    static let ii = Harmony(degree: 1)
    static let IV = Harmony(degree: 3)
    static let V = Harmony(degree: 4)
    static let V7 = Harmony(degree: 4, seventh: true)
    static let vi = Harmony(degree: 5)

    /// Distancia diatónica (0–6) de una nota a la fundamental del acorde.
    func interval(_ diatonic: Int, tonic: Int) -> Int {
        ((diatonic - tonic - degree) % 7 + 7) % 7
    }

    func contains(_ diatonic: Int, tonic: Int) -> Bool {
        let i = interval(diatonic, tonic: tonic)
        return i == 0 || i == 2 || i == 4 || (seventh && i == 6)
    }
}

/// Un acorde por medio compás (4/4, 6/8) o por compás (2/4, 3/4); termina en V–I como en el libro.
struct HarmonyPlan {
    let slotTicks: Int
    let chords: [Harmony]

    func at(_ tick: Int) -> Harmony {
        chords[min(max(tick / slotTicks, 0), chords.count - 1)]
    }

    static func make(meter: Meter, measures: Int) -> HarmonyPlan {
        let perMeasure = (meter == .fourFour || meter == .sixEight) ? 2 : 1
        let count = perMeasure * measures
        var chords: [Harmony]
        switch count {
        case 1:
            chords = [.I]
        case 2:
            let options: [[Harmony]] = [[.I, .V], [.I, .V7], [.IV, .I], [.V7, .I]]
            chords = options.randomElement()!
        default:
            chords = [.I]
            for _ in 0..<(count - 3) {
                chords.append([Harmony.IV, .ii, .vi, .I, .V].randomElement()!)
            }
            chords.append(Bool.random() ? .V7 : .V)
            chords.append(.I)
        }
        return HarmonyPlan(slotTicks: meter.measureTicks / perMeasure, chords: chords)
    }
}

extension KeySignature {
    /// Letra de la tónica mayor (0 = C … 6 = B).
    var tonicLetter: Int { ((fifths * 4) % 7 + 7) % 7 }
}

extension RhythmGenerator {
    /// Rango para leer: el del pentagrama más el espacio de arriba y el de abajo (sin líneas adicionales).
    func readingRange(_ clef: Clef) -> ClosedRange<Int> {
        let range = clef.range(ledgerLines: settings.ledgerLines)
        return settings.ledgerLines ? range : (range.lowerBound - 1)...(range.upperBound + 1)
    }

    // MARK: - Melodía

    /// Pone alturas a los eventos de una mano que lleva la melodía: notas del acorde en los tiempos,
    /// pasos (notas de paso y bordaduras) entre ellos, dentro de la posición de la mano; termina en la tónica.
    /// G3–A4: la izquierda en clave de sol, como en los primeros números del libro.
    static let leftTrebleRange = 25...33

    func assignMelody(_ events: inout [RhythmEvent], clef: Clef, key: KeySignature, plan: HarmonyPlan, meter: Meter,
                      range fixedRange: ClosedRange<Int>? = nil) {
        let tonic = key.tonicLetter
        var range = fixedRange ?? readingRange(clef)
        if clef == .treble && settings.clef == .both && settings.leftHandTreble {
            // La izquierda ocupa G3–A4: la derecha empieza en G4, como en los primeros números del libro.
            range = max(range.lowerBound, 32)...range.upperBound
        }
        let window = handWindow(range: range, tonic: tonic)
        let beat = meter == .sixEight ? 72 : 48
        let kinds = settings.kinds.filter { $0 != .progression }
        let sounding = events.indices.filter { !events[$0].isRest }
        guard !sounding.isEmpty else { return }

        func chordTones(_ harmony: Harmony) -> [Int] {
            window.filter { harmony.contains($0, tonic: tonic) }
        }
        func nearest(_ options: [Int], to target: Int, maxJump: Int) -> Int? {
            let close = options.filter { abs($0 - target) <= maxJump }
            let pool = close.isEmpty ? options : close
            // Repetir la misma nota cuesta más; lo normal es moverse por grado o por tercera.
            let weighted = pool.flatMap { d -> [Int] in
                let distance = abs(d - target)
                return Array(repeating: d, count: distance == 0 ? 1 : max(1, 4 - distance))
            }
            return weighted.randomElement()
        }

        let maxJump = settings.motion == .free ? 5 : (settings.motion == .octave ? 4 : 2)
        var previous = window[window.count / 2]
        var direction = Bool.random() ? 1 : -1

        for (n, i) in sounding.enumerated() {
            let tick = events[i].tick
            let harmony = plan.at(tick)
            let strong = tick % beat == 0
            let isLast = n == sounding.count - 1
            var pitch: Int

            if n == 0 {
                pitch = nearest(chordTones(harmony), to: window[window.count / 2], maxJump: 3) ?? previous
            } else if isLast {
                // Cierre: la tónica si está cerca; si no, otra nota del acorde de tónica.
                let tonics = window.filter { (($0 - tonic) % 7 + 7) % 7 == 0 }
                if let home = tonics.min(by: { abs($0 - previous) < abs($1 - previous) }), abs(home - previous) <= 4 {
                    pitch = home
                } else {
                    pitch = nearest(chordTones(.I), to: previous, maxJump: 4) ?? previous
                }
            } else if strong {
                pitch = nearest(chordTones(harmony), to: previous, maxJump: maxJump) ?? previous
            } else if settings.motion == .free && Double.random(in: 0..<1) < 0.2 {
                pitch = nearest(chordTones(harmony), to: previous, maxJump: maxJump) ?? previous
            } else {
                // Paso: sigue la dirección; en el borde de la posición, da la vuelta.
                if Double.random(in: 0..<1) < 0.25 { direction = -direction }
                if !window.contains(previous + direction) { direction = -direction }
                pitch = window.contains(previous + direction) ? previous + direction : previous
            }
            direction = pitch > previous ? 1 : (pitch < previous ? -1 : direction)
            previous = pitch

            // Nota, intervalo (tercera o sexta debajo) o tríada (con la melodía arriba).
            var kind = kinds.randomElement() ?? .single
            if kind == .triad && !harmony.contains(pitch, tonic: tonic) { kind = kinds.contains(.interval) ? .interval : .single }
            switch kind {
            case .interval:
                let below = settings.motion != .fixed && Double.random(in: 0..<1) < 0.3 ? 5 : 2
                if pitch - below >= range.lowerBound {
                    events[i].notes = [key.note(pitch - below), key.note(pitch)]
                } else {
                    events[i].notes = [key.note(pitch), key.note(pitch + 2)]
                }
            case .triad:
                var lower: [Int] = []
                var d = pitch - 1
                while lower.count < 2 && d > pitch - 7 {
                    if harmony.contains(d, tonic: tonic) && !(harmony.seventh && harmony.interval(d, tonic: tonic) == 0) {
                        lower.insert(d, at: 0)
                    }
                    d -= 1
                }
                events[i].notes = (lower + [pitch]).map { key.note($0) }
            default:
                // Alteraciones accidentales en notas de paso (bordaduras cromáticas, Nos. 36 en adelante).
                let altered = settings.accidentals && !strong && !isLast && Double.random(in: 0..<1) < 0.25
                events[i].notes = [altered ? key.altered(pitch) : key.note(pitch)]
            }
        }
    }

    /// Notas que alcanza la mano: cinco (sobre la tónica o la dominante), una octava sobre la tónica, o todo el rango.
    private func handWindow(range: ClosedRange<Int>, tonic: Int) -> [Int] {
        func starts(width: Int, degrees: Set<Int>) -> [Int] {
            stride(from: range.lowerBound, through: range.upperBound - width, by: 1)
                .filter { degrees.contains((($0 - tonic) % 7 + 7) % 7) }
        }
        let width: Int
        let degrees: Set<Int>
        switch settings.motion {
        case .fixed: width = 4; degrees = [0, 4]
        case .octave: width = 7; degrees = [0]
        case .free: return Array(range)
        }
        let options = starts(width: width, degrees: degrees)
        let fallback = starts(width: min(width, range.count - 1), degrees: Set(0..<7))
        guard let start = (options.isEmpty ? fallback : options).randomElement() else { return Array(range) }
        return Array(start...(start + width))
    }

    // MARK: - Acompañamiento (mano izquierda con las dos manos)

    private enum Pattern: CaseIterable {
        /// Notas o acordes largos, uno por acorde (Nos. 9–11).
        case held
        /// Bajo y acorde alternados en negras.
        case oomPah
        /// Vals: bajo y dos acordes (No. 21).
        case waltz
        /// Bajo de Alberti en corcheas: 1-5-3-5 (No. 14).
        case alberti
        /// Acorde quebrado en corcheas (Nos. 20, 23, 34).
        case broken
        /// Acorde quebrado en tresillos (Nos. 15, 31).
        case triplets
        /// Acordes en los tiempos separados por silencios (No. 43).
        case restChords
    }

    private func patterns(meter: Meter, features: Set<RhythmFeature>) -> [Pattern] {
        var list: [Pattern] = [.held]
        let duple = meter == .twoFour || meter == .fourFour
        if duple { list.append(.oomPah) }
        if meter == .threeFour { list.append(.waltz) }
        if features.contains(.eighths) {
            if duple { list.append(.alberti) }
            list.append(.broken)
        }
        if features.contains(.triplets) && meter != .sixEight { list.append(.triplets) }
        if features.contains(.rests) && meter != .sixEight { list.append(.restChords) }
        return list
    }

    /// La mano izquierda acompaña la armonía de la melodía con un patrón del libro.
    func accompaniment(key: KeySignature, plan: HarmonyPlan, meter: Meter, measures: Int,
                       features: Set<RhythmFeature>) -> Voice {
        let tonic = key.tonicLetter
        let clef: Clef = settings.leftHandTreble ? .treble : .bass
        // En clave de sol la izquierda lee alrededor del do central (G3–A4), como en los Nos. 1–31.
        let range = settings.leftHandTreble ? Self.leftTrebleRange : readingRange(.bass)
        let kinds = settings.kinds.filter { $0 != .progression }
        let chords = kinds.contains(.triad) ? 3 : (kinds.contains(.interval) ? 2 : 1)
        let pattern = patterns(meter: meter, features: features).randomElement() ?? .held
        let beat = meter == .sixEight ? 72 : 48

        var events: [RhythmEvent] = []
        var group = 0
        var previousVoicing: [Int] = []

        func fit(_ d: Int) -> Int {
            var d = d
            while d > range.upperBound { d -= 7 }
            while d < range.lowerBound { d += 7 }
            return d
        }
        /// Fundamental en el registro grave, con espacio para la quinta encima.
        func root(_ harmony: Harmony) -> Int {
            let letter = (tonic + harmony.degree) % 7
            let options = Array(range).filter { (($0 % 7) + 7) % 7 == letter }
            return options.first { $0 + 4 <= range.upperBound } ?? options.first ?? range.lowerBound
        }
        /// Acorde de bloque con la disposición más cercana al anterior (Czerny: I, V7 como B-D-F, IV como C-F-A).
        func block(_ harmony: Harmony, size: Int) -> [Int] {
            let r = root(harmony)
            if size == 1 { return [r] }
            if size == 2 { return Bool.random() ? [r, r + 4] : [r, r + 2] }
            var options: [[Int]] = [[r, r + 2, r + 4], [r + 2, r + 4, r + 7], [r + 4, r + 7, r + 9]]
            if harmony.seventh { options.append([r + 2, r + 4, r + 6]) }
            options = options.filter { $0.allSatisfy { range.contains($0) } }
            guard !options.isEmpty else { return [r, r + 2, r + 4].map(fit).sorted() }
            if previousVoicing.isEmpty { return options[0] }
            let center = previousVoicing.reduce(0, +) / previousVoicing.count
            return options.min { abs($0.reduce(0, +) / 3 - center) < abs($1.reduce(0, +) / 3 - center) }!
        }
        /// Notas de arriba para oom-pah y vals: tercera y quinta (o solo la quinta).
        func upper(_ harmony: Harmony) -> [Int] {
            let r = root(harmony)
            switch chords {
            case 1: return [fit(r + 4)]
            case 2: return [r + 2, r + 4].map(fit).sorted()
            default:
                return (harmony.seventh ? [r + 2, r + 4, r + 6] : [r + 4, r + 7, r + 9]).map(fit).sorted()
            }
        }

        func add(_ tick: Int, _ item: CellItem, _ pitches: [Int], start: Bool,
                 beam: Int? = nil, tuplet: Int? = nil) {
            var event = RhythmEvent(tick: tick, item: item, measure: tick / meter.measureTicks,
                                    cellStart: start, tupletGroup: tuplet)
            event.notes = item.rest ? [] : pitches.sorted().map { key.note($0) }
            event.beamGroup = beam
            events.append(event)
        }
        func n(_ v: NoteValue, dot: Bool = false, tri: Bool = false) -> CellItem {
            CellItem(value: v, dotted: dot, triplet: tri)
        }

        let total = meter.measureTicks * measures
        var tick = 0
        while tick < total {
            let harmony = plan.at(tick)
            let slotEnd = min(total, (tick / plan.slotTicks + 1) * plan.slotTicks)
            let r = root(harmony)

            switch pattern {
            case .held:
                let v = block(harmony, size: chords)
                previousVoicing = v
                // La duración del acorde: redonda, blanca, blanca con puntillo… o negras si no hay figuras largas.
                var t = tick
                var first = true
                while t < slotEnd {
                    let left = slotEnd - t
                    let item: CellItem
                    if features.contains(.long) && left >= 192 { item = n(.whole) }
                    else if features.contains(.long) && left >= 144 && (features.contains(.dotted) || meter == .sixEight) { item = n(.half, dot: true) }
                    else if features.contains(.long) && left >= 96 { item = n(.half) }
                    else if left >= 72 && meter == .sixEight { item = n(.quarter, dot: true) }
                    else { item = n(.quarter) }
                    add(t, item, v, start: first)
                    first = false
                    t += item.ticks
                }

            case .oomPah, .waltz, .restChords:
                var t = tick
                var k = 0
                while t < slotEnd {
                    let pitches: [Int]
                    var rest = false
                    switch pattern {
                    case .oomPah: pitches = k % 2 == 0 ? [r] : upper(harmony)
                    case .waltz: pitches = k == 0 ? [r] : upper(harmony)
                    default:
                        pitches = block(harmony, size: chords)
                        rest = k % 2 == 1
                    }
                    if !rest { previousVoicing = pitches }
                    add(t, CellItem(value: .quarter, rest: rest), pitches, start: k == 0)
                    k += 1
                    t += 48
                }

            case .alberti, .broken:
                let shape: [Int] = {
                    if pattern == .alberti { return [0, 4, 2, 4] }
                    return meter == .sixEight ? [0, 2, 4] : [0, 4, 7, 4]
                }()
                var t = tick
                var k = 0
                while t < slotEnd {
                    let beam = group + (t - tick) / beat
                    add(t, n(.eighth), [fit(r + shape[k % shape.count])], start: k == 0, beam: beam)
                    k += 1
                    t += 24
                }
                group += (slotEnd - tick) / beat + 1

            case .triplets:
                var t = tick
                var k = 0
                while t < slotEnd {
                    let id = group + (t - tick) / 48
                    add(t, n(.eighth, tri: true), [fit(r + [0, 2, 4][k % 3])], start: k == 0, beam: id, tuplet: id)
                    k += 1
                    t += 16
                }
                group += (slotEnd - tick) / 48 + 1
            }
            tick = slotEnd
        }
        return Voice(clef: clef, events: events, slurs: [])
    }
}
