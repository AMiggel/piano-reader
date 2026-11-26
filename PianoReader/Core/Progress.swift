import Foundation
import Observation

/// Estrellas por nivel (0–3). Un nivel se desbloquea con al menos 1 estrella en el anterior.
@Observable
final class ProgressStore {
    private static let key = "levelStars"

    private(set) var stars: [Int: Int] {
        didSet {
            if let data = try? JSONEncoder().encode(stars) {
                UserDefaults.standard.set(data, forKey: Self.key)
            }
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Int: Int].self, from: data) {
            stars = saved
        } else {
            stars = [:]
        }
    }

    /// Estrellas según los ejercicios perfectos de una sesión completa.
    static func stars(cleanRatio: Double) -> Int {
        switch cleanRatio {
        case 0.95...: 3
        case 0.8...: 2
        case 0.6...: 1
        default: 0
        }
    }

    static let passText = "Para pasar: 60% de ejercicios perfectos (★), 80% (★★), 95% (★★★)."

    func stars(for level: Int) -> Int { stars[level] ?? 0 }

    func isUnlocked(_ level: Int) -> Bool {
        level <= 1 || stars(for: level - 1) > 0
    }

    /// El nivel que toca: el primero desbloqueado sin estrellas (o el último).
    var currentLevel: Int {
        Level.all.first { isUnlocked($0.number) && stars(for: $0.number) == 0 }?.number
            ?? Level.all.last?.number ?? 1
    }

    var totalStars: Int { stars.values.reduce(0, +) }

    /// Guarda el mejor resultado. Devuelve true si con esto se desbloqueó el siguiente nivel.
    @discardableResult
    func record(level: Int, stars earned: Int) -> Bool {
        let wasUnlocked = isUnlocked(level + 1)
        if earned > stars(for: level) { stars[level] = earned }
        return !wasUnlocked && isUnlocked(level + 1) && Level.number(level + 1) != nil
    }

    func reset() { stars = [:] }
}
