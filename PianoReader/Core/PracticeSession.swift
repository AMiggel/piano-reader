import Foundation
import Observation
import SwiftUI

struct ExerciseResult: Identifiable {
    let id = UUID()
    let exercise: Exercise
    let time: TimeInterval
    let errors: Int
}

@Observable
final class PracticeSession {
    enum Feedback { case none, correct, wrong }

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
    @ObservationIgnored private var feedbackToken = 0

    init(settings: PracticeSettings) {
        let generator = ExerciseGenerator(settings: settings)
        self.settings = settings
        self.generator = generator
        exercise = generator.next(after: nil)
    }

    var isFinished: Bool { finishedAt != nil }
    var elapsed: TimeInterval { frozenElapsed ?? Date().timeIntervalSince(startedAt) }
    var totalErrors: Int { results.reduce(0) { $0 + $1.errors } + currentErrors }
    var averageTime: TimeInterval? {
        results.isEmpty ? nil : results.reduce(0) { $0 + $1.time } / Double(results.count)
    }

    func key(_ midi: Int) -> Int { settings.exactOctave ? midi : ((midi % 12) + 12) % 12 }

    private var targetKeys: Set<Int> { Set(exercise.steps[stepIndex].map { key($0.midi) }) }

    func noteOn(_ midi: Int) {
        guard frozenElapsed == nil, !isFinished else { return }
        lastPlayed = midi
        let k = key(midi)
        let target = targetKeys
        if target.contains(k) {
            hits.insert(k)
            if hits == target { completeStep() }
        } else {
            currentErrors += 1
            hits.removeAll()
            show(.wrong)
        }
    }

    /// En acordes hay que mantener las teclas juntas: soltar una la quita.
    func noteOff(_ midi: Int) {
        guard frozenElapsed == nil, !isFinished, exercise.steps[stepIndex].count > 1 else { return }
        hits.remove(key(midi))
    }

    func finish() {
        finishedAt = Date()
    }

    func restart() {
        results = []
        sessionStartedAt = Date()
        finishedAt = nil
        lastPlayed = nil
        loadNext()
    }

    /// Color de una nota en pantalla; nil = color normal.
    func color(step: Int, note: Note) -> Color? {
        if step < stepIndex { return .green }
        if step > stepIndex { return Color(white: 0.55) }
        switch feedback {
        case .correct: return .green
        case .wrong: return .red
        case .none: return hits.contains(key(note.midi)) ? .green : nil
        }
    }

    private func completeStep() {
        hits.removeAll()
        if stepIndex < exercise.steps.count - 1 {
            stepIndex += 1
            return
        }
        let time = Date().timeIntervalSince(startedAt)
        frozenElapsed = time
        results.append(ExerciseResult(exercise: exercise, time: time, errors: currentErrors))
        show(.correct)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, !self.isFinished else { return }
            if self.settings.sessionLength > 0 && self.results.count >= self.settings.sessionLength {
                self.finish()
            } else {
                self.loadNext()
            }
        }
    }

    private func loadNext() {
        exercise = generator.next(after: exercise)
        stepIndex = 0
        hits = []
        currentErrors = 0
        feedback = .none
        frozenElapsed = nil
        startedAt = Date()
    }

    private func show(_ value: Feedback) {
        feedbackToken += 1
        let token = feedbackToken
        feedback = value
        guard value == .wrong else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.feedbackToken == token, self.feedback == .wrong else { return }
            self.feedback = .none
        }
    }
}
