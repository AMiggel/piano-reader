import Foundation
import Observation

/// Progreso de las unidades. Cada unidad tiene práctica (0–3 estrellas) y una evaluación final con una obra
/// del libro (0–3 estrellas). La evaluación se abre con 1 estrella de práctica; la unidad siguiente,
/// al aprobar la evaluación (o con 1 estrella de práctica si la unidad no tiene obra).
@Observable
final class ProgressStore {
    /// Claves nuevas al pasar a las unidades de Czerny: las estrellas de los niveles anteriores no aplican.
    private static let key = "czernyStars"
    private static let examKey = "czernyExams"

    private(set) var stars: [Int: Int] {
        didSet { Self.save(stars, Self.key) }
    }
    private(set) var exams: [Int: Int] {
        didSet { Self.save(exams, Self.examKey) }
    }

    init() {
        stars = Self.load(Self.key)
        exams = Self.load(Self.examKey)
    }

    private static func save(_ value: [Int: Int], _ key: String) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }

    private static func load(_ key: String) -> [Int: Int] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([Int: Int].self, from: data) else { return [:] }
        return saved
    }

    /// Estrellas de práctica según los ejercicios perfectos de una sesión completa.
    static func stars(cleanRatio: Double) -> Int {
        switch cleanRatio {
        case 0.95...: 3
        case 0.8...: 2
        case 0.6...: 1
        default: 0
        }
    }

    /// Estrellas de la evaluación según las notas tocadas bien en toda la obra.
    static func examStars(accuracy: Double) -> Int {
        switch accuracy {
        case 0.97...: 3
        case 0.9...: 2
        case 0.8...: 1
        default: 0
        }
    }

    static let passText = "Para pasar: 60% de ejercicios perfectos (★), 80% (★★), 95% (★★★)."
    static let examPassText = "Para aprobar: 80% de notas bien (★), 90% (★★), 97% (★★★)."

    func stars(for level: Int) -> Int { stars[level] ?? 0 }
    func examStars(for level: Int) -> Int { exams[level] ?? 0 }

    func hasExam(_ level: Int) -> Bool { Level.number(level)?.pieceData != nil }

    func isExamUnlocked(_ level: Int) -> Bool { stars(for: level) > 0 }

    /// Unidad terminada: evaluación aprobada (o práctica con estrella si no tiene obra).
    func isPassed(_ level: Int) -> Bool {
        hasExam(level) ? examStars(for: level) > 0 : stars(for: level) > 0
    }

    func isUnlocked(_ level: Int) -> Bool {
        Level.number(level - 1) == nil || isPassed(level - 1) // la primera de cada recorrido está abierta
    }

    /// La unidad que toca: la primera abierta sin terminar (o la última).
    var currentLevel: Int { current(in: Level.all) }

    /// La unidad que toca dentro de un recorrido (lectura o ritmo).
    func current(in track: [Level]) -> Int {
        track.first { isUnlocked($0.number) && !isPassed($0.number) }?.number
            ?? track.last?.number ?? 1
    }

    var totalStars: Int { stars.values.reduce(0, +) + exams.values.reduce(0, +) }
    var maxStars: Int { (Level.all + Level.rhythm).reduce(0) { $0 + 3 + (hasExam($1.number) ? 3 : 0) } }

    /// Guarda el mejor resultado de práctica. Devuelve true si con esto se abrió algo nuevo
    /// (la evaluación, o la unidad siguiente si no hay evaluación).
    @discardableResult
    func record(level: Int, stars earned: Int) -> Bool {
        let before = (isExamUnlocked(level), isUnlocked(level + 1))
        if earned > stars(for: level) { stars[level] = earned }
        let after = (isExamUnlocked(level), isUnlocked(level + 1))
        return (!before.0 && after.0) || (!before.1 && after.1 && Level.number(level + 1) != nil)
    }

    /// Guarda el mejor resultado de la evaluación. Devuelve true si se abrió la unidad siguiente.
    @discardableResult
    func recordExam(level: Int, stars earned: Int) -> Bool {
        let wasUnlocked = isUnlocked(level + 1)
        if earned > examStars(for: level) { exams[level] = earned }
        return !wasUnlocked && isUnlocked(level + 1) && Level.number(level + 1) != nil
    }

    func reset() {
        stars = [:]
        exams = [:]
    }
}
