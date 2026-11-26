import Foundation
import Observation

enum ClefChoice: String, CaseIterable, Identifiable, Codable {
    case treble, bass, both
    var id: String { rawValue }

    var label: String {
        switch self {
        case .treble: "Sol"
        case .bass: "Fa"
        case .both: "Ambas"
        }
    }

    func pick() -> Clef {
        switch self {
        case .treble: .treble
        case .bass: .bass
        case .both: Bool.random() ? .treble : .bass
        }
    }
}

enum ExerciseKind: String, CaseIterable, Identifiable, Codable {
    case single, interval, triad, progression
    var id: String { rawValue }

    var label: String {
        switch self {
        case .single: "Nota"
        case .interval: "Dos notas"
        case .triad: "Tríada"
        case .progression: "Progresión"
        }
    }
}

enum DisplayMode: String, CaseIterable, Identifiable, Codable {
    case staff, name, both
    var id: String { rawValue }

    var label: String {
        switch self {
        case .staff: "Partitura"
        case .name: "Nombre"
        case .both: "Ambos"
        }
    }
}

struct PracticeSettings: Codable, Equatable {
    var clef: ClefChoice = .treble
    var kinds: Set<ExerciseKind> = [.single]
    var progressionLength = 4
    var ledgerLines = false
    var accidentals = false
    var exactOctave = false
    var display: DisplayMode = .staff
    var naming: NamingStyle = .english
    /// 0 = sin límite.
    var sessionLength = 20
}

@Observable
final class SettingsStore {
    private static let key = "practiceSettings"

    var settings: PracticeSettings {
        didSet {
            if let data = try? JSONEncoder().encode(settings) {
                UserDefaults.standard.set(data, forKey: Self.key)
            }
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(PracticeSettings.self, from: data) {
            settings = saved
        } else {
            settings = PracticeSettings()
        }
    }
}
