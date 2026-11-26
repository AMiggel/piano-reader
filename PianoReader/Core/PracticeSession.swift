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

/// Referencia a un evento: voz (0 = mano derecha o la única, 1 = izquierda) e índice.
struct EventRef: Hashable {
    let voice: Int
    let index: Int
}

/// Un solo modo: compases con figuras, notas sueltas, intervalos o tríadas, con una o dos manos.
/// - Con metrónomo: un compás de cuenta y se juzga cuándo empieza cada nota
///   (±60 ms perfecto, ±130 ms bien) y cuánto se mantiene.
/// - Sin metrónomo: tocas en orden a tu ritmo; si fallas, repites esa nota.
/// Lo que empieza a la vez en las dos manos se toca y se juzga junto.
/// Puntos × racha (×2 desde 5 ejercicios perfectos seguidos, ×3 desde 10, ×4 desde 15) × ½ con pista.
@Observable
final class PracticeSession {
    /// Todo lo que empieza en el mismo momento (en una o las dos manos).
    struct Onset {
        let refs: [EventRef]
        let tick: Int
        let keys: Set<Int>
        let notes: [(midi: Int, duration: TimeInterval)]
        let time: TimeInterval
        /// Antes de esto, soltar la tecla es error (por tecla).
        let minRelease: [Int: TimeInterval]
        let window: TimeInterval
        let slurredKeys: Set<Int>
        let tiedKeys: Set<Int>

        var midis: [Int] { notes.map(\.midi) }
    }

    private(set) var settings: PracticeSettings
    @ObservationIgnored private var generator: RhythmGenerator
    /// Obra completa en tramos (evaluación final).
    private let script: [RhythmExercise]?
    @ObservationIgnored private var scriptIndex = 0
    var isExam: Bool { script != nil }

    private(set) var exercise: RhythmExercise
    @ObservationIgnored private(set) var onsets: [Onset]
    @ObservationIgnored private var onsetOf: [EventRef: Int] = [:]
    /// Juicio por índice de `onsets`.
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
    /// La sesión llegó al número de ejercicios (no se terminó antes con "Terminar").
    private(set) var completed = false
    private(set) var bpm = 80
    private(set) var metronomeOn = false

    // Con metrónomo
    /// Momento (systemUptime) en que empieza el ejercicio; antes de eso es la cuenta.
    private(set) var t0: TimeInterval?
    @ObservationIgnored private var holds: [Int: Int] = [:]
    @ObservationIgnored private var pending: [Int: (keys: Set<Int>, first: TimeInterval)] = [:]

    // Sin metrónomo
    /// Índice de `onsets` que toca ahora.
    private(set) var current = 0
    private(set) var hits: Set<Int> = []
    private(set) var wrongFlash = false
    @ObservationIgnored private var onsetErrors: [Int] = []
    @ObservationIgnored private var exerciseStart = Date()
    @ObservationIgnored private var locked = false
    @ObservationIgnored private var flashToken = 0

    /// `script`: una obra completa en tramos (evaluación final); sin él, ejercicios generados.
    init(settings initial: PracticeSettings, script: [RhythmExercise]? = nil) {
        var settings = initial
        settings.pickMeter()
        if let first = script?.first {
            settings.meter = first.meter
            settings.meters = [first.meter]
            settings.sessionLength = script?.count ?? 0
            settings.repeatOnFail = false
        }
        let generator = RhythmGenerator(settings: settings)
        let exercise = script?.first ?? generator.make()
        self.script = script
        self.settings = settings
        self.generator = generator
        self.exercise = exercise
        bpm = settings.bpm
        metronomeOn = settings.metronome
        onsets = Self.buildOnsets(exercise, settings, bpm: settings.bpm)
        onsetOf = Self.index(onsets, exercise)
        resetAttempt()
    }

    var isFinished: Bool { finishedAt != nil }
    /// Proporción de notas (momentos) tocadas bien en toda la sesión.
    var noteAccuracy: Double {
        let all = results.flatMap { $0.judgments }
        return all.isEmpty ? 0 : Double(all.filter { $0.isClean }.count) / Double(all.count)
    }

    /// Proporción de ejercicios perfectos (0…1).
    var cleanRatio: Double { results.isEmpty ? 0 : Double(results.filter { $0.clean }.count) / Double(results.count) }
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

    /// Lo que hay que tocar ahora (sin metrónomo) — o lo siguiente sin juzgar (con metrónomo).
    var currentIndex: Int? {
        if metronomeOn { return onsets.indices.first { judgments[$0] == nil } }
        return onsets.indices.contains(current) ? current : nil
    }

    var currentOnset: Onset? { currentIndex.map { onsets[$0] } }

    /// Notas del momento actual con su voz (para dibujar lo que tocas junto a ellas).
    var currentNotes: [(voice: Int, note: Note)] {
        guard let onset = currentOnset else { return [] }
        return onset.refs.flatMap { ref in
            exercise.voices[ref.voice].events[ref.index].notes.map { (voice: ref.voice, note: $0) }
        }
    }

    // MARK: - Ajustes durante la práctica

    func setTempo(_ value: Int) {
        guard value != bpm, !isFinished else { return }
        bpm = value
        restartAttempt()
    }

    /// Compás distinto = ejercicio nuevo escrito en ese compás (y se queda en ese compás esta sesión).
    func setMeter(_ meter: Meter) {
        guard meter != settings.meter, !isFinished, script == nil else { return }
        settings.meter = meter
        settings.meters = [meter]
        generator = RhythmGenerator(settings: settings)
        attempt = 1
        load(generator.make())
        t0 = nil
    }

    /// El metrónomo se reinició (otro compás o tempo): el próximo clic vuelve a arrancar la cuenta.
    func restartCount() {
        t0 = nil
    }

    /// Ejercicio nuevo; si hay varios compases elegidos, sale uno al azar.
    private func nextExercise() -> RhythmExercise {
        if let script {
            scriptIndex = min(scriptIndex + 1, script.count - 1)
            return script[scriptIndex]
        }
        let before = settings.meter
        settings.pickMeter()
        if settings.meter != before { generator = RhythmGenerator(settings: settings) }
        return generator.make()
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

    /// Posición en ticks de la línea azul: con metrónomo sigue el tiempo; sin él, marca lo que toca.
    func playheadTick(now: TimeInterval) -> Double? {
        if let demoStart {
            let tick = (now - demoStart) / secondsPerTick
            return tick >= 0 && tick <= Double(exercise.totalTicks) ? tick : nil
        }
        if !metronomeOn { return currentOnset.map { Double($0.tick) } }
        guard let t0 else { return nil }
        let tick = (now - t0) / secondsPerTick
        return tick >= 0 && tick <= Double(exercise.totalTicks) ? tick : nil
    }

    func color(voice: Int, index: Int) -> Color? {
        let events = exercise.voices[voice].events
        guard events.indices.contains(index), !events[index].isRest else { return nil }
        var i = index
        while i > 0 && events[i].tiedFromPrevious { i -= 1 }
        guard let onset = onsetOf[EventRef(voice: voice, index: i)] else { return nil }
        if let judgment = judgments[onset] { return judgment.color }
        if !metronomeOn && onset == current {
            if wrongFlash { return .red }
            if !hits.isEmpty { return .blue }
        }
        return nil
    }

    /// Notas de la pista con su momento relativo al inicio del ejercicio.
    var hintNotes: [(start: TimeInterval, midi: Int, duration: TimeInterval)] {
        onsets.flatMap { onset in
            onset.notes.map { (start: onset.time, midi: $0.midi, duration: $0.duration * 0.95) }
        }
    }

    // MARK: - Escuchar (demostración)

    /// Mientras suena la demostración: la línea avanza con el sonido y no se evalúa nada.
    private(set) var demoStart: TimeInterval?
    var isDemoPlaying: Bool { demoStart != nil }
    /// Lo que dura la demostración (el ejercicio a este tempo).
    var demoDuration: TimeInterval { duration }

    /// Empieza la demostración en `start` (systemUptime). El ejercicio vale la mitad.
    func startDemo(at start: TimeInterval) {
        guard !isFinished else { return }
        load(exercise)
        t0 = nil
        hintUsed = true
        demoStart = start
    }

    /// Termina la demostración: el intento vuelve a empezar (con su cuenta si hay metrónomo).
    func stopDemo() {
        guard demoStart != nil else { return }
        demoStart = nil
        load(exercise)
        t0 = nil
        hintUsed = true
    }

    // MARK: - Entrada

    func useHint() {
        guard !isFinished else { return }
        hintUsed = true
    }

    func beat(at time: TimeInterval) {
        guard metronomeOn, !isFinished, demoStart == nil else { return }
        guard let t0 else {
            self.t0 = time + countInDuration
            return
        }
        if script != nil {
            // Obra completa: los tramos siguen de corrido, sin otra cuenta.
            if time >= t0 + duration - 0.02 { advanceScript() } else { markMisses(now: time) }
            return
        }
        if time >= t0 + duration - 0.02 {
            let meter = settings.meter
            finishTimedAttempt()
            guard !isFinished else { return }
            // Otro compás: la vista reinicia el metrónomo y su primer clic arranca la cuenta.
            self.t0 = settings.meter == meter ? time + countInDuration : nil
        } else {
            markMisses(now: time)
        }
    }

    func noteOn(_ midi: Int, at time: TimeInterval) {
        guard !isFinished, demoStart == nil else { return }
        if metronomeOn { timedNoteOn(midi, at: time) } else { freeNoteOn(midi) }
    }

    func noteOff(_ midi: Int, at time: TimeInterval) {
        guard !isFinished, demoStart == nil else { return }
        if metronomeOn { timedNoteOff(midi, at: time) } else { freeNoteOff(midi) }
    }

    func finish() {
        guard !isFinished else { return }
        finishedAt = Date()
        saveRecords()
    }

    func restart() {
        scriptIndex = -1
        results = []
        score = 0
        streak = 0
        bestStreak = 0
        attempt = 1
        sessionStartedAt = Date()
        finishedAt = nil
        completed = false
        message = nil
        t0 = nil
        load(nextExercise())
    }

    // MARK: - Con metrónomo

    /// Cierra el tramo actual de la obra y empieza el siguiente justo donde terminó.
    private func advanceScript() {
        guard let start = t0 else { return }
        let end = start + duration
        finishTimedAttempt()
        guard !isFinished else { return }
        t0 = end
    }

    private func timedNoteOn(_ midi: Int, at time: TimeInterval) {
        // En la obra, una nota un poco adelantada al principio del tramo siguiente ya pertenece a ese tramo.
        if script != nil, let start = t0, let last = onsets.last,
           time - start > max(last.time + last.window, duration - 0.15) {
            advanceScript()
        }
        guard let t0 else { return }
        let rel = time - t0
        guard rel > -0.35, rel < duration + 0.3 else { return } // durante la cuenta no se evalúa
        markMisses(now: time)
        let k = key(midi)

        guard let i = onsets.indices.first(where: {
            judgments[$0] == nil && abs(rel - onsets[$0].time) <= onsets[$0].window
        }) else {
            errors += 1
            let repeatedTie = holds.contains { $0.key == k && onsets[$0.value].tiedKeys.contains(k) }
            say(repeatedTie ? "Nota ligada: no se vuelve a tocar" : "Nota de más", .red)
            return
        }
        let onset = onsets[i]
        guard onset.keys.contains(k) else {
            judgments[i] = .wrongNote
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
            judgments[i] = judgment
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
        guard let minRelease = onset.minRelease[k], time - t0 < minRelease,
              judgments[i]?.wasPlayed == true else { return }
        judgments[i] = .short
        say(onset.slurredKeys.contains(k) ? "Sin legato: mantén hasta la siguiente"
            : onset.tiedKeys.contains(k) ? "Mantén la nota ligada" : "La soltaste antes", .red)
    }

    private func markMisses(now: TimeInterval) {
        guard let t0 else { return }
        let rel = now - t0
        for (i, onset) in onsets.enumerated() where judgments[i] == nil && rel > onset.time + onset.window {
            let judgment: Judgment = pending[i] != nil ? .wrongNote : .miss // acorde incompleto
            pending[i] = nil
            judgments[i] = judgment
            say(judgment == .miss ? Judgment.miss.label : "Acorde incompleto", .red)
        }
    }

    private func finishTimedAttempt() {
        for i in onsets.indices where judgments[i] == nil {
            judgments[i] = .miss
        }
        var value = 0.0
        for (i, onset) in onsets.enumerated() {
            value += Double((judgments[i] ?? .miss).points * onset.keys.count)
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
        if reachedLimit() { completed = true; finish(); return }
        if repeating {
            attempt += 1
            load(exercise)
        } else {
            attempt = 1
            load(nextExercise())
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

    /// En acordes (o las dos manos a la vez) hay que mantener las teclas juntas: soltar una la quita.
    private func freeNoteOff(_ midi: Int) {
        guard !locked, let onset = currentOnset, onset.keys.count > 1 else { return }
        hits.remove(key(midi))
    }

    private func completeOnset() {
        judgments[current] = onsetErrors[current] == 0 ? .perfect : .retried
        hits = []
        current += 1
        guard current >= onsets.count else { return }

        // Ejercicio terminado
        let seconds = Date().timeIntervalSince(exerciseStart)
        let perNote = seconds / Double(max(onsets.count, 1))
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
            if self.reachedLimit() { self.completed = true; self.finish(); return }
            self.attempt = 1
            self.load(self.nextExercise())
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
        let list = onsets.indices.map { judgments[$0] ?? .miss }
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
        onsetOf = Self.index(onsets, next)
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

    private static func index(_ onsets: [Onset], _ exercise: RhythmExercise) -> [EventRef: Int] {
        var map: [EventRef: Int] = [:]
        for (i, onset) in onsets.enumerated() {
            for ref in onset.refs { map[ref] = i }
        }
        return map
    }

    private static func buildOnsets(_ exercise: RhythmExercise, _ settings: PracticeSettings, bpm: Int) -> [Onset] {
        let secondsPerTick = 60 / Double(bpm) / Double(settings.meter.ticksPerClick)

        struct Part {
            let ref: EventRef
            let start: Int
            let ticks: Int
            let midis: [Int]
            let slurred: Bool
            let tied: Bool
        }
        var parts: [Part] = []
        for (v, voice) in exercise.voices.enumerated() {
            let events = voice.events
            for (i, e) in events.enumerated() where !e.isRest && !e.tiedFromPrevious {
                var ticks = e.item.ticks
                var j = i
                while events[j].tiedToNext && j + 1 < events.count {
                    j += 1
                    ticks += events[j].item.ticks
                }
                let slurred = voice.slurs.contains { $0.contains(i) && $0.upperBound != i }
                parts.append(Part(ref: EventRef(voice: v, index: i), start: e.tick, ticks: ticks,
                                  midis: e.notes.map(\.midi), slurred: slurred, tied: e.tiedToNext))
            }
        }

        let groups = Dictionary(grouping: parts, by: \.start)
        let starts = groups.keys.sorted()
        return starts.indices.map { k in
            let start = starts[k]
            let group = groups[start] ?? []
            let time = Double(start) * secondsPerTick
            let prevGap = k > 0 ? time - Double(starts[k - 1]) * secondsPerTick : 10
            let nextGap = k < starts.count - 1 ? Double(starts[k + 1]) * secondsPerTick - time : 10
            let window = min(0.3, max(0.1, 0.45 * min(prevGap, nextGap)))

            var notes: [(midi: Int, duration: TimeInterval)] = []
            var minRelease: [Int: TimeInterval] = [:]
            var slurredKeys: Set<Int> = []
            var tiedKeys: Set<Int> = []
            for part in group {
                let length = Double(part.ticks) * secondsPerTick
                for midi in part.midis {
                    let pk = key(midi, settings)
                    notes.append((midi: midi, duration: length))
                    let release = part.slurred ? time + length - 0.08 : time + length * 0.6
                    minRelease[pk] = min(minRelease[pk] ?? release, release)
                    if part.slurred { slurredKeys.insert(pk) }
                    if part.tied { tiedKeys.insert(pk) }
                }
            }
            return Onset(
                refs: group.map(\.ref),
                tick: start,
                keys: Set(notes.map { key($0.midi, settings) }),
                notes: notes,
                time: time,
                minRelease: minRelease,
                window: window,
                slurredKeys: slurredKeys,
                tiedKeys: tiedKeys
            )
        }
    }
}
