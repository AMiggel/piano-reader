import Foundation
import Observation
import SwiftUI

struct ExerciseResult: Identifiable {
    let id = UUID()
    let exercise: Exercise
    let time: TimeInterval
    let errors: Int
    let points: Int
    let usedHint: Bool
    let timedOut: Bool
}

/// Puntaje: 10 por nota × precisión (−30% por fallo, mín. 20%)
/// × velocidad (sin metrónomo: rapidez; con metrónomo: tempo y tiempo disponible)
/// × racha (×1, ×2 desde 5, ×3 desde 10, ×4 desde 15) × ½ si usaste la pista.
/// Racha = ejercicios seguidos sin fallos ni tiempo agotado.
@Observable
final class PracticeSession {
    enum Feedback { case none, correct, wrong, timeout }

    let settings: PracticeSettings
    @ObservationIgnored private let generator: ExerciseGenerator

    private(set) var exercise: Exercise
    private(set) var stepIndex = 0
    /// Teclas correctas ya presionadas en el paso actual (clase de nota u octava exacta).
    private(set) var hits: Set<Int> = []
    private(set) var feedback: Feedback = .none
    private(set) var currentErrors = 0
    private(set) var results: [ExerciseResult] = []
    private(set) var lastPlayed: Int?
    private(set) var startedAt = Date()
    private(set) var sessionStartedAt = Date()
    private(set) var finishedAt: Date?
    /// Tiempo congelado mientras se muestra "¡Correcto!".
    private(set) var frozenElapsed: TimeInterval?

    private(set) var score = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var hintUsed = false
    private(set) var lastPoints = 0

    // Metrónomo
    /// Se puede apagar/encender durante la práctica (empieza como en los ajustes).
    private(set) var metronomeOn = false
    /// Tempo actual (se puede cambiar durante la práctica).
    private(set) var bpm = 80
    /// Antes del primer ejercicio: un compás de cuenta.
    private(set) var isWaitingStart = false
    private(set) var countInRemaining = 0
    private(set) var beatsLeft = 0
    @ObservationIgnored private var advanceOnNextBeat = false
    @ObservationIgnored private var feedbackToken = 0

    init(settings: PracticeSettings) {
        let generator = ExerciseGenerator(settings: settings)
        self.settings = settings
        self.generator = generator
        exercise = generator.next(after: nil)
        metronomeOn = settings.metronome
        bpm = settings.bpm
        if metronomeOn { startCountIn() }
    }

    func setTempo(_ value: Int) {
        bpm = value
    }

    /// Apagar: sin límite de tiempo y sin esperar al tiempo siguiente. Encender: cuenta un compás y sigue.
    func setMetronome(_ on: Bool) {
        guard on != metronomeOn, !isFinished else { return }
        metronomeOn = on
        if on {
            startCountIn()
        } else {
            countInRemaining = 0
            beatsLeft = 0
            if isWaitingStart {
                isWaitingStart = false
                startedAt = Date()
            }
            if advanceOnNextBeat {
                advanceOnNextBeat = false
                advance()
            }
        }
    }

    var isFinished: Bool { finishedAt != nil }
    var acceptsInput: Bool { !isFinished && !isWaitingStart && frozenElapsed == nil }
    var elapsed: TimeInterval { isWaitingStart ? 0 : frozenElapsed ?? Date().timeIntervalSince(startedAt) }
    var totalErrors: Int { results.reduce(0) { $0 + $1.errors } + currentErrors }
    var multiplier: Int { min(1 + streak / 5, 4) }
    var windowBeats: Int { settings.window.beats(settings.meter) * exercise.steps.count }
    var countInBeat: Int { settings.meter.beats - countInRemaining }

    var averageTime: TimeInterval? {
        let done = results.filter { !$0.timedOut }
        return done.isEmpty ? nil : done.reduce(0) { $0 + $1.time } / Double(done.count)
    }

    func key(_ midi: Int) -> Int { settings.exactOctave ? midi : ((midi % 12) + 12) % 12 }

    private var targetKeys: Set<Int> { Set(exercise.steps[stepIndex].map { key($0.midi) }) }

    // MARK: - Entrada

    func noteOn(_ midi: Int) {
        guard acceptsInput else { return }
        lastPlayed = midi
        let k = key(midi)
        let target = targetKeys
        if target.contains(k) {
            hits.insert(k)
            if hits == target { completeStep() }
        } else {
            currentErrors += 1
            streak = 0
            hits.removeAll()
            show(.wrong)
        }
    }

    /// En acordes hay que mantener las teclas juntas: soltar una la quita.
    func noteOff(_ midi: Int) {
        guard acceptsInput, exercise.steps[stepIndex].count > 1 else { return }
        hits.remove(key(midi))
    }

    /// Pista de sonido: el ejercicio vale la mitad.
    func useHint() {
        guard acceptsInput else { return }
        hintUsed = true
    }

    /// Lo llama el metrónomo en cada tiempo.
    func beat() {
        guard metronomeOn, !isFinished else { return }
        if countInRemaining > 0 {
            countInRemaining -= 1
            if countInRemaining == 0 { advanceOnNextBeat = true }
            return
        }
        if advanceOnNextBeat {
            advanceOnNextBeat = false
            if isWaitingStart {
                isWaitingStart = false
                startedAt = Date()
            } else {
                advance()
            }
            beatsLeft = windowBeats
            return
        }
        guard frozenElapsed == nil else { return }
        beatsLeft -= 1
        if beatsLeft <= 0 { timeOut() }
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
        sessionStartedAt = Date()
        finishedAt = nil
        lastPlayed = nil
        loadNext()
        if metronomeOn { startCountIn() }
    }

    /// Color de una nota en pantalla; nil = color normal.
    func color(step: Int, note: Note) -> Color? {
        if step < stepIndex { return .green }
        if step > stepIndex { return Color(white: 0.55) }
        switch feedback {
        case .correct: return .green
        case .wrong, .timeout: return .red
        case .none: return hits.contains(key(note.midi)) ? .green : nil
        }
    }

    // MARK: - Flujo

    private func completeStep() {
        hits.removeAll()
        if stepIndex < exercise.steps.count - 1 {
            stepIndex += 1
            return
        }
        let time = Date().timeIntervalSince(startedAt)
        frozenElapsed = time
        let earned = points(time: time)
        score += earned
        lastPoints = earned
        if currentErrors == 0 {
            streak += 1
            bestStreak = max(bestStreak, streak)
        }
        results.append(ExerciseResult(exercise: exercise, time: time, errors: currentErrors,
                                      points: earned, usedHint: hintUsed, timedOut: false))
        saveRecords()
        show(.correct)

        if metronomeOn {
            advanceOnNextBeat = true // el siguiente aparece en el próximo tiempo
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self, !self.isFinished else { return }
                self.advance()
            }
        }
    }

    private func timeOut() {
        results.append(ExerciseResult(exercise: exercise, time: elapsed, errors: currentErrors,
                                      points: 0, usedHint: hintUsed, timedOut: true))
        streak = 0
        advance()
        beatsLeft = windowBeats
        show(.timeout)
    }

    private func advance() {
        if settings.sessionLength > 0 && results.count >= settings.sessionLength {
            finish()
        } else {
            loadNext()
        }
    }

    private func loadNext() {
        exercise = generator.next(after: exercise)
        stepIndex = 0
        hits = []
        currentErrors = 0
        hintUsed = false
        feedback = .none
        frozenElapsed = nil
        startedAt = Date()
    }

    private func startCountIn() {
        isWaitingStart = true
        countInRemaining = settings.meter.beats
        advanceOnNextBeat = false
        beatsLeft = 0
    }

    private func points(time: TimeInterval) -> Int {
        let notes = exercise.steps.reduce(0) { $0 + $1.count }
        var value = Double(10 * notes)
        value *= max(0.2, 1 - 0.3 * Double(currentErrors))
        if metronomeOn {
            value *= min(max(Double(bpm) / 80, 0.75), 2) * settings.window.speedFactor
        } else {
            let perNote = time / Double(notes)
            value *= perNote < 1.5 ? 1.5 : perNote < 3 ? 1.25 : 1
        }
        value *= Double(multiplier)
        if hintUsed { value *= 0.5 }
        return Int(value.rounded())
    }

    private func saveRecords() {
        let defaults = UserDefaults.standard
        if score > defaults.integer(forKey: "bestScore") { defaults.set(score, forKey: "bestScore") }
        if bestStreak > defaults.integer(forKey: "bestStreak") { defaults.set(bestStreak, forKey: "bestStreak") }
    }

    private func show(_ value: Feedback) {
        feedbackToken += 1
        let token = feedbackToken
        feedback = value
        guard value == .wrong || value == .timeout else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.feedbackToken == token, self.feedback == value else { return }
            self.feedback = .none
        }
    }
}
