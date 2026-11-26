import Foundation
import Observation
import SwiftUI

enum Judgment {
    case perfect, good, early, late, wrongNote, miss, short, retried

    var color: Color {
        switch self {
        case .perfect, .good: .green
        case .early, .late, .retried: .orange
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
        case .retried: "Correcta tras fallar"
        }
    }

    /// Puntos por nota con metrónomo.
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

struct PracticeResult: Identifiable {
    let id = UUID()
    let exercise: RhythmExercise
    let judgments: [Judgment]
    /// Notas de más (con metrónomo) o teclas equivocadas (sin metrónomo).
    let errors: Int
    let points: Int
    let usedHint: Bool
    let attempt: Int
    let timed: Bool
    /// Segundos por nota/acorde (sin metrónomo).
    let secondsPerNote: TimeInterval?

    var clean: Bool { errors == 0 && judgments.allSatisfy(\.isClean) }
    var onTime: Int { judgments.filter(\.isClean).count }
}

/// Un solo modo: un compás con figuras, notas sueltas, intervalos o tríadas.
/// - Con metrónomo: un compás de cuenta y se juzga cuándo empieza cada nota
///   (±60 ms perfecto, ±130 ms bien) y cuánto se mantiene.
/// - Sin metrónomo: tocas las notas en orden a tu ritmo; si fallas, repites esa nota.
/// Puntos × racha (×2 desde 5 ejercicios perfectos seguidos, ×3 desde 10, ×4 desde 15) × ½ con pista.
@Observable
final class PracticeSession {
    struct Onset {
        let event: Int
        let keys: Set<Int>
        let midis: [Int]
        let time: TimeInterval
        let duration: TimeInterval
        let minRelease: TimeInterval
        let window: TimeInterval
        let slurred: Bool
        let tied: Bool
    }

    private(set) var settings: PracticeSettings
    @ObservationIgnored private var generator: RhythmGenerator

    private(set) var exercise: RhythmExercise
    @ObservationIgnored private(set) var onsets: [Onset]
    /// Juicio por índice de evento (solo eventos donde empieza una nota).
    private(set) var judgments: [Int: Judgment] = [:]
    private(set) var errors = 0
    private(set) var message: String?
    private(set) var messageColor: Color = .secondary
    private(set) var score = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var results: [PracticeResult] = []
    private(set) var hintUsed = false
    private(set) var attempt = 1
    private(set) var sessionStartedAt = Date()
    private(set) var finishedAt: Date?
    private(set) var bpm = 80
    private(set) var metronomeOn = false

    // Con metrónomo
    /// Momento (systemUptime) en que empieza el ejercicio; antes de eso es la cuenta.
    private(set) var t0: TimeInterval?
    @ObservationIgnored private var holds: [Int: Int] = [:]
    @ObservationIgnored private var pending: [Int: (keys: Set<Int>, first: TimeInterval)] = [:]

    // Sin metrónomo
    /// Nota/acorde que toca ahora.
    private(set) var current = 0
    private(set) var hits: Set<Int> = []
    private(set) var wrongFlash = false
    @ObservationIgnored private var onsetErrors: [Int] = []
    @ObservationIgnored private var onsetStart = Date()
    @ObservationIgnored private var exerciseStart = Date()
    @ObservationIgnored private var locked = false
    @ObservationIgnored private var flashToken = 0

    init(settings: PracticeSettings) {
        let generator = RhythmGenerator(settings: settings)
        let exercise = generator.make()
        self.settings = settings
        self.generator = generator
        self.exercise = exercise
        bpm = settings.bpm
        metronomeOn = settings.metronome
        onsets = Self.buildOnsets(exercise, settings, bpm: settings.bpm)
        resetAttempt()
    }

    var isFinished: Bool { finishedAt != nil }
    var secondsPerClick: TimeInterval { 60 / Double(bpm) }
    var secondsPerTick: TimeInterval { secondsPerClick / Double(settings.meter.ticksPerClick) }
    var duration: TimeInterval { Double(exercise.totalTicks) * secondsPerTick }
    var countInDuration: TimeInterval { Double(settings.meter.beats) * secondsPerClick }
    var multiplier: Int { min(1 + streak / 5, 4) }
    var hasStarted: Bool { t0 != nil }
    var totalErrors: Int { results.reduce(0) { $0 + $1.errors } + errors }

    static func now() -> TimeInterval { ProcessInfo.processInfo.systemUptime }

    func key(_ midi: Int) -> Int { Self.key(midi, settings) }

    static func key(_ midi: Int, _ settings: PracticeSettings) -> Int {
        settings.exactOctave ? midi : ((midi % 12) + 12) % 12
    }

    /// Nota/acorde que hay que tocar ahora (sin metrónomo) — o el siguiente sin juzgar (con metrónomo).
    var currentOnset: Onset? {
        if metronomeOn { return onsets.first { judgments[$0.event] == nil } }
        return onsets.indices.contains(current) ? onsets[current] : nil
    }

    // MARK: - Ajustes durante la práctica

    func setTempo(_ value: Int) {
        guard value != bpm, !isFinished else { return }
        bpm = value
        restartAttempt()
    }

    /// Compás distinto = ejercicio nuevo escrito en ese compás.
    func setMeter(_ meter: Meter) {
        guard meter != settings.meter, !isFinished else { return }
        settings.meter = meter
        generator = RhythmGenerator(settings: settings)
        attempt = 1
        load(generator.make())
        t0 = nil
    }

    /// Encender: se evalúa el ritmo (vuelve a empezar el compás con su cuenta). Apagar: a tu ritmo.
    func setMetronome(_ on: Bool) {
        guard on != metronomeOn, !isFinished else { return }
        metronomeOn = on
        restartAttempt()
    }

    private func restartAttempt() {
        load(exercise)
        t0 = nil // con metrónomo, el próximo clic arranca la cuenta
    }

    // MARK: - Para la vista

    func countInBeat(now: TimeInterval) -> Int? {
        guard metronomeOn, let t0, now < t0 else { return nil }
        let remaining = Int(((t0 - now) / secondsPerClick - 0.001).rounded(.up))
        return max(1, settings.meter.beats - remaining + 1)
    }

    /// Posición en ticks de la línea azul: con metrónomo sigue el tiempo; sin él, marca la nota actual.
    func playheadTick(now: TimeInterval) -> Double? {
        if !metronomeOn {
            return currentOnset.map { Double(exercise.events[$0.event].tick) }
        }
        guard let t0 else { return nil }
        let tick = (now - t0) / secondsPerTick
        return tick >= 0 && tick <= Double(exercise.totalTicks) ? tick : nil
    }

    func color(event index: Int) -> Color? {
        let events = exercise.events
        guard events.indices.contains(index), !events[index].isRest else { return nil }
        var i = index
        while i > 0 && events[i].tiedFromPrevious { i -= 1 }
        if let judgment = judgments[i] { return judgment.color }
        if !metronomeOn, let onset = currentOnset, onset.event == i {
            if wrongFlash { return .red }
            if !hits.isEmpty { return .blue }
        }
        return nil
    }

    /// Notas de la pista con su momento relativo al inicio del ejercicio.
    var hintNotes: [(start: TimeInterval, midi: Int, duration: TimeInterval)] {
        onsets.flatMap { onset in
            onset.midis.map { (start: onset.time, midi: $0, duration: onset.duration * 0.95) }
        }
    }

    // MARK: - Entrada

    func useHint() {
        guard !isFinished else { return }
        hintUsed = true
    }

    func beat(at time: TimeInterval) {
        guard metronomeOn, !isFinished else { return }
        guard let t0 else {
            self.t0 = time + countInDuration
            return
        }
        if time >= t0 + duration - 0.02 {
            finishTimedAttempt()
            guard !isFinished else { return }
            self.t0 = time + countInDuration
        } else {
            markMisses(now: time)
        }
    }

    func noteOn(_ midi: Int, at time: TimeInterval) {
        guard !isFinished else { return }
        if metronomeOn { timedNoteOn(midi, at: time) } else { freeNoteOn(midi) }
    }

    func noteOff(_ midi: Int, at time: TimeInterval) {
        guard !isFinished else { return }
        if metronomeOn { timedNoteOff(midi, at: time) } else { freeNoteOff(midi) }
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

    // MARK: - Con metrónomo

    private func timedNoteOn(_ midi: Int, at time: TimeInterval) {
        guard let t0 else { return }
        let rel = time - t0
        guard rel > -0.35, rel < duration + 0.3 else { return } // durante la cuenta no se evalúa
        markMisses(now: time)
        let k = key(midi)

        guard let i = onsets.indices.first(where: {
            judgments[onsets[$0].event] == nil && abs(rel - onsets[$0].time) <= onsets[$0].window
        }) else {
            errors += 1
            let repeatedTie = holds.contains { $0.key == k && onsets[$0.value].tied }
            say(repeatedTie ? "Nota ligada: no se vuelve a tocar" : "Nota de más", .red)
            return
        }
        let onset = onsets[i]
        guard onset.keys.contains(k) else {
            judgments[onset.event] = .wrongNote
            pending[i] = nil
            say(Judgment.wrongNote.label, .red)
            return
        }
        holds[k] = i
        var chord = pending[i] ?? (keys: [], first: rel)
        chord.keys.insert(k)
        if chord.keys == onset.keys {
            pending[i] = nil
            let d = chord.first - onset.time
            let judgment: Judgment = abs(d) <= 0.06 ? .perfect : abs(d) <= 0.13 ? .good : (d < 0 ? .early : .late)
            judgments[onset.event] = judgment
            say(judgment.label, judgment.color)
        } else {
            pending[i] = chord
        }
    }

    private func timedNoteOff(_ midi: Int, at time: TimeInterval) {
        guard let t0 else { return }
        let k = key(midi)
        guard let i = holds.removeValue(forKey: k) else { return }
        if var chord = pending[i] {
            chord.keys.remove(k)
            pending[i] = chord.keys.isEmpty ? nil : chord
            return
        }
        let onset = onsets[i]
        guard time - t0 < onset.minRelease, judgments[onset.event]?.wasPlayed == true else { return }
        judgments[onset.event] = .short
        say(onset.slurred ? "Sin legato: mantén hasta la siguiente"
            : onset.tied ? "Mantén la nota ligada" : "La soltaste antes", .red)
    }

    private func markMisses(now: TimeInterval) {
        guard let t0 else { return }
        let rel = now - t0
        for (i, onset) in onsets.enumerated() where judgments[onset.event] == nil && rel > onset.time + onset.window {
            let judgment: Judgment = pending[i] != nil ? .wrongNote : .miss // acorde incompleto
            pending[i] = nil
            judgments[onset.event] = judgment
            say(judgment == .miss ? Judgment.miss.label : "Acorde incompleto", .red)
        }
    }

    private func finishTimedAttempt() {
        for onset in onsets where judgments[onset.event] == nil {
            judgments[onset.event] = .miss
        }
        var value = 0.0
        for onset in onsets {
            value += Double((judgments[onset.event] ?? .miss).points * onset.keys.count)
        }
        value = max(0, value - Double(errors * 5))
        value *= min(max(Double(bpm) / 80, 0.75), 2)
        record(points: value, timed: true, secondsPerNote: nil)

        let result = results[results.count - 1]
        let repeating = settings.repeatOnFail && !result.clean
        if result.clean {
            say("¡Compás perfecto! +\(result.points)", .green)
        } else {
            say("\(result.onTime)/\(result.judgments.count) a tiempo · +\(result.points)" + (repeating ? " · otra vez" : ""), .orange)
        }
        if reachedLimit() { finish(); return }
        if repeating {
            attempt += 1
            load(exercise)
        } else {
            attempt = 1
            load(generator.make())
        }
    }

    // MARK: - Sin metrónomo

    private func freeNoteOn(_ midi: Int) {
        guard !locked, let onset = currentOnset else { return }
        let k = key(midi)
        if onset.keys.contains(k) {
            hits.insert(k)
            if hits == onset.keys { completeOnset() }
        } else {
            errors += 1
            onsetErrors[current] += 1
            streak = 0
            hits = []
            say("Otra vez", .red)
            flashWrong()
        }
    }

    /// En acordes hay que mantener las teclas juntas: soltar una la quita.
    private func freeNoteOff(_ midi: Int) {
        guard !locked, let onset = currentOnset, onset.keys.count > 1 else { return }
        hits.remove(key(midi))
    }

    private func completeOnset() {
        let onset = onsets[current]
        judgments[onset.event] = onsetErrors[current] == 0 ? .perfect : .retried
        hits = []
        current += 1
        onsetStart = Date()
        guard current >= onsets.count else { return }

        // Ejercicio terminado
        let seconds = Date().timeIntervalSince(exerciseStart)
        let noteCount = max(onsets.count, 1)
        let perNote = seconds / Double(noteCount)
        var value = 0.0
        for (i, onset) in onsets.enumerated() {
            value += Double(10 * onset.keys.count) * max(0.2, 1 - 0.3 * Double(onsetErrors[i]))
        }
        value *= perNote < 1.5 ? 1.5 : perNote < 3 ? 1.25 : 1
        record(points: value, timed: false, secondsPerNote: perNote)

        let result = results[results.count - 1]
        say(result.clean ? "¡Perfecto! +\(result.points)" : "Completado · +\(result.points)", result.clean ? .green : .orange)
        locked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self, !self.isFinished, !self.metronomeOn else { return }
            if self.reachedLimit() { self.finish(); return }
            self.attempt = 1
            self.load(self.generator.make())
        }
    }

    private func flashWrong() {
        flashToken += 1
        let token = flashToken
        wrongFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.flashToken == token else { return }
            self.wrongFlash = false
        }
    }

    // MARK: - Común

    private func record(points raw: Double, timed: Bool, secondsPerNote: TimeInterval?) {
        var value = raw * Double(multiplier)
        if hintUsed { value *= 0.5 }
        let list = onsets.map { judgments[$0.event] ?? .miss }
        let result = PracticeResult(exercise: exercise, judgments: list, errors: errors,
                                    points: Int(value.rounded()), usedHint: hintUsed, attempt: attempt,
                                    timed: timed, secondsPerNote: secondsPerNote)
        results.append(result)
        score += result.points
        if result.clean {
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            streak = 0
        }
        saveRecords()
    }

    private func reachedLimit() -> Bool {
        settings.sessionLength > 0 && results.count >= settings.sessionLength
    }

    private func load(_ next: RhythmExercise) {
        exercise = next
        onsets = Self.buildOnsets(next, settings, bpm: bpm)
        resetAttempt()
    }

    private func resetAttempt() {
        judgments = [:]
        errors = 0
        holds = [:]
        pending = [:]
        hintUsed = false
        current = 0
        hits = []
        wrongFlash = false
        onsetErrors = Array(repeating: 0, count: onsets.count)
        onsetStart = Date()
        exerciseStart = Date()
        locked = false
    }

    private func say(_ text: String, _ color: Color) {
        message = text
        messageColor = color
    }

    private func saveRecords() {
        let defaults = UserDefaults.standard
        if score > defaults.integer(forKey: "bestScore") { defaults.set(score, forKey: "bestScore") }
        if bestStreak > defaults.integer(forKey: "bestStreak") { defaults.set(bestStreak, forKey: "bestStreak") }
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
            let midis = events[r.event].notes.map(\.midi)
            return Onset(
                event: r.event,
                keys: Set(midis.map { key($0, settings) }),
                midis: midis,
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
