import Foundation
import Observation
import SwiftUI

enum Judgment {
    case perfect, good, early, late, wrongNote, miss, short

    var color: Color {
        switch self {
        case .perfect, .good: .green
        case .early, .late: .orange
        case .wrongNote, .miss, .short: .red
        }
    }

    var label: String {
        switch self {
        case .perfect: "¡Perfecto!"
        case .good: "Bien"
        case .early: "Adelantado"
        case .late: "Atrasado"
        case .wrongNote: "Nota equivocada"
        case .miss: "No la tocaste"
        case .short: "La soltaste antes"
        }
    }

    var points: Int {
        switch self {
        case .perfect: 10
        case .good: 7
        case .early, .late: 4
        default: 0
        }
    }

    var isClean: Bool { self == .perfect || self == .good }
    var wasPlayed: Bool { self == .perfect || self == .good || self == .early || self == .late }
}

struct RhythmResult: Identifiable {
    let id = UUID()
    let exercise: RhythmExercise
    let judgments: [Judgment]
    let extras: Int
    let points: Int
    let usedHint: Bool
    let attempt: Int

    var clean: Bool { extras == 0 && judgments.allSatisfy(\.isClean) }
    var onTime: Int { judgments.filter(\.isClean).count }
}

/// Modo ritmo: el metrónomo no para; cada ejercicio = 1 compás de cuenta + el ejercicio.
/// Cada nota se juzga por cuándo empieza (±60 ms perfecto, ±130 ms bien) y cuánto se mantiene.
@Observable
final class RhythmSession {
    struct Onset {
        let event: Int
        let key: Int
        let midi: Int
        let time: TimeInterval
        let duration: TimeInterval
        let minRelease: TimeInterval
        let window: TimeInterval
        let slurred: Bool
        let tied: Bool
    }

    let settings: PracticeSettings
    @ObservationIgnored private let generator: RhythmGenerator

    private(set) var exercise: RhythmExercise
    @ObservationIgnored private(set) var onsets: [Onset]
    /// Juicio por índice de evento (solo eventos donde empieza una nota).
    private(set) var judgments: [Int: Judgment] = [:]
    private(set) var extras = 0
    /// Momento (systemUptime) en que empieza el ejercicio; antes de eso es la cuenta.
    private(set) var t0: TimeInterval?
    private(set) var message: String?
    private(set) var messageColor: Color = .secondary
    private(set) var score = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var results: [RhythmResult] = []
    private(set) var hintUsed = false
    private(set) var attempt = 1
    private(set) var sessionStartedAt = Date()
    private(set) var finishedAt: Date?
    /// Tecla mantenida → índice en `onsets`.
    @ObservationIgnored private var holds: [Int: Int] = [:]
    /// Tempo actual (se puede cambiar durante la práctica).
    private(set) var bpm = 80

    init(settings: PracticeSettings) {
        let generator = RhythmGenerator(settings: settings)
        let exercise = generator.make()
        self.settings = settings
        self.generator = generator
        self.exercise = exercise
        bpm = settings.bpm
        onsets = Self.buildOnsets(exercise, settings, bpm: settings.bpm)
    }

    /// Cambia el tempo durante la práctica: el compás actual vuelve a empezar con su cuenta.
    func setTempo(_ value: Int) {
        guard value != bpm, !isFinished else { return }
        bpm = value
        load(exercise)
        t0 = nil // el próximo clic arranca la cuenta
        say("Tempo: \(value) BPM", .secondary)
    }

    var isFinished: Bool { finishedAt != nil }
    var secondsPerClick: TimeInterval { 60 / Double(bpm) }
    var secondsPerTick: TimeInterval { secondsPerClick / Double(settings.meter.ticksPerClick) }
    var duration: TimeInterval { Double(exercise.totalTicks) * secondsPerTick }
    var countInDuration: TimeInterval { Double(settings.meter.beats) * secondsPerClick }
    var multiplier: Int { min(1 + streak / 5, 4) }
    var hasStarted: Bool { t0 != nil }

    static func now() -> TimeInterval { ProcessInfo.processInfo.systemUptime }

    func key(_ midi: Int) -> Int { Self.key(midi, settings) }

    static func key(_ midi: Int, _ settings: PracticeSettings) -> Int {
        settings.exactOctave ? midi : ((midi % 12) + 12) % 12
    }

    // MARK: - Para la vista

    /// Número de la cuenta (1, 2, 3…) o nil si ya está sonando el ejercicio.
    func countInBeat(now: TimeInterval) -> Int? {
        guard let t0, now < t0 else { return nil }
        let remaining = Int(((t0 - now) / secondsPerClick - 0.001).rounded(.up))
        return max(1, settings.meter.beats - remaining + 1)
    }

    /// Posición actual en ticks (para la línea de reproducción).
    func playheadTick(now: TimeInterval) -> Double? {
        guard let t0 else { return nil }
        let tick = (now - t0) / secondsPerTick
        return tick >= 0 && tick <= Double(exercise.totalTicks) ? tick : nil
    }

    func color(event index: Int) -> Color? {
        let events = exercise.events
        guard events.indices.contains(index), !events[index].isRest else { return nil }
        var i = index
        while i > 0 && events[i].tiedFromPrevious { i -= 1 }
        return judgments[i]?.color
    }

    /// Notas de la pista con su momento relativo al inicio del ejercicio.
    var hintNotes: [(start: TimeInterval, midi: Int, duration: TimeInterval)] {
        onsets.map { (start: $0.time, midi: $0.midi, duration: $0.duration * 0.95) }
    }

    // MARK: - Entrada

    func beat(at time: TimeInterval) {
        guard !isFinished else { return }
        guard let t0 else {
            self.t0 = time + countInDuration
            return
        }
        if time >= t0 + duration - 0.02 {
            finalizeAttempt()
            guard !isFinished else { return }
            self.t0 = time + countInDuration
        } else {
            markMisses(now: time)
        }
    }

    func noteOn(_ midi: Int, at time: TimeInterval) {
        guard let t0, !isFinished else { return }
        let rel = time - t0
        guard rel > -0.35, rel < duration + 0.3 else { return } // durante la cuenta no se evalúa
        markMisses(now: time)
        let k = key(midi)

        if let i = onsets.indices.first(where: { judgments[onsets[$0].event] == nil && abs(rel - onsets[$0].time) <= onsets[$0].window }) {
            let onset = onsets[i]
            let judgment: Judgment
            if onset.key == k {
                let d = rel - onset.time
                judgment = abs(d) <= 0.06 ? .perfect : abs(d) <= 0.13 ? .good : (d < 0 ? .early : .late)
                holds[k] = i
            } else {
                judgment = .wrongNote
            }
            judgments[onset.event] = judgment
            say(judgment.label, judgment.color)
        } else {
            extras += 1
            let repeatedTie = holds.contains { $0.key == k && onsets[$0.value].tied }
            say(repeatedTie ? "Nota ligada: no se vuelve a tocar" : "Nota de más", .red)
        }
    }

    func noteOff(_ midi: Int, at time: TimeInterval) {
        guard let t0 else { return }
        let k = key(midi)
        guard let i = holds.removeValue(forKey: k) else { return }
        let onset = onsets[i]
        guard time - t0 < onset.minRelease, judgments[onset.event]?.wasPlayed == true else { return }
        judgments[onset.event] = .short
        let text = onset.slurred ? "Sin legato: mantén hasta la siguiente"
            : onset.tied ? "Mantén la nota ligada"
            : "La soltaste antes"
        say(text, .red)
    }

    func useHint() {
        guard !isFinished else { return }
        hintUsed = true
    }

    func finish() {
        guard !isFinished else { return }
        finishedAt = Date()
        saveRecords()
    }

    func restart() {
        results = []
        score = 0
        streak = 0
        bestStreak = 0
        attempt = 1
        sessionStartedAt = Date()
        finishedAt = nil
        message = nil
        t0 = nil
        load(generator.make())
    }

    // MARK: - Flujo

    private func markMisses(now: TimeInterval) {
        guard let t0 else { return }
        let rel = now - t0
        for onset in onsets where judgments[onset.event] == nil && rel > onset.time + onset.window {
            judgments[onset.event] = .miss
            say(Judgment.miss.label, Judgment.miss.color)
        }
    }

    private func finalizeAttempt() {
        for onset in onsets where judgments[onset.event] == nil {
            judgments[onset.event] = .miss
        }
        let list = onsets.map { judgments[$0.event] ?? .miss }
        var value = Double(max(0, list.reduce(0) { $0 + $1.points } - extras * 5))
        value *= min(max(Double(bpm) / 80, 0.75), 2)
        value *= Double(multiplier)
        if hintUsed { value *= 0.5 }

        let result = RhythmResult(exercise: exercise, judgments: list, extras: extras,
                                  points: Int(value.rounded()), usedHint: hintUsed, attempt: attempt)
        results.append(result)
        score += result.points
        if result.clean {
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            streak = 0
        }
        saveRecords()

        let repeating = settings.repeatOnFail && !result.clean
        if result.clean {
            say("¡Compás perfecto! +\(result.points)", .green)
        } else {
            say("\(result.onTime)/\(list.count) a tiempo · +\(result.points)" + (repeating ? " · otra vez" : ""), .orange)
        }

        if settings.sessionLength > 0 && results.count >= settings.sessionLength {
            finish()
            return
        }
        if repeating {
            attempt += 1
            load(exercise)
        } else {
            attempt = 1
            load(generator.make())
        }
    }

    private func load(_ next: RhythmExercise) {
        exercise = next
        onsets = Self.buildOnsets(next, settings, bpm: bpm)
        judgments = [:]
        extras = 0
        holds = [:]
        hintUsed = false
    }

    private func say(_ text: String, _ color: Color) {
        message = text
        messageColor = color
    }

    private func saveRecords() {
        let defaults = UserDefaults.standard
        if score > defaults.integer(forKey: "rhythmBestScore") { defaults.set(score, forKey: "rhythmBestScore") }
        if bestStreak > defaults.integer(forKey: "rhythmBestStreak") { defaults.set(bestStreak, forKey: "rhythmBestStreak") }
    }

    private static func buildOnsets(_ exercise: RhythmExercise, _ settings: PracticeSettings, bpm: Int) -> [Onset] {
        let secondsPerTick = 60 / Double(bpm) / Double(settings.meter.ticksPerClick)
        let events = exercise.events

        var raw: [(event: Int, start: Int, ticks: Int)] = []
        for (i, e) in events.enumerated() where !e.isRest && !e.tiedFromPrevious {
            var ticks = e.item.ticks
            var j = i
            while events[j].tiedToNext && j + 1 < events.count {
                j += 1
                ticks += events[j].item.ticks
            }
            raw.append((i, e.tick, ticks))
        }

        return raw.indices.map { k in
            let r = raw[k]
            let time = Double(r.start) * secondsPerTick
            let length = Double(r.ticks) * secondsPerTick
            let prevGap = k > 0 ? time - Double(raw[k - 1].start) * secondsPerTick : 10
            let nextGap = k < raw.count - 1 ? Double(raw[k + 1].start) * secondsPerTick - time : 10
            let window = min(0.3, max(0.1, 0.45 * min(prevGap, nextGap)))
            let slurred = exercise.slurs.contains { $0.contains(r.event) && $0.upperBound != r.event }
            let midi = events[r.event].note?.midi ?? 60
            return Onset(
                event: r.event,
                key: key(midi, settings),
                midi: midi,
                time: time,
                duration: length,
                minRelease: slurred ? time + length - 0.08 : time + length * 0.6,
                window: window,
                slurred: slurred,
                tied: events[r.event].tiedToNext
            )
        }
    }
}
