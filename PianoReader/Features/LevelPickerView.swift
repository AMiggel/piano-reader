import SwiftUI

/// Elegir un nivel: aplica sus ajustes (menos el nombre de las notas) y vuelve atrás.
struct LevelPickerView: View {
    @Bindable var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(Level.all) { level in
            Button {
                level.apply(to: &store.settings)
                dismiss()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(level.number)")
                        .font(.title3.bold().monospacedDigit())
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(level.title).font(.headline)
                        Text(level.summary)
                        Text(detail(level))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Spacer()
                    if store.settings.level == level.number {
                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Niveles")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(_ level: Level) -> String {
        let keys = level.keys.count >= 15 ? "Todas las tonalidades"
            : level.keys.sorted().map { KeySignature(fifths: $0).majorName }.joined(separator: ", ")
        let kinds = ExerciseKind.selectable.filter { level.kinds.contains($0) }.map(\.label).joined(separator: ", ")
        let figures = (["Negras"] + RhythmFeature.allCases.filter { level.features.contains($0) }.map(\.label))
            .joined(separator: ", ")
        var reading: [String] = []
        if level.exactOctave { reading.append("octava exacta") }
        if level.accidentals { reading.append("alteraciones") }
        if level.ledgerLines { reading.append("líneas adicionales") }
        var lines = [keys, kinds, figures]
        if !reading.isEmpty { lines.append(reading.joined(separator: ", ").capitalizedFirst) }
        if level.bpm != nil { lines.append(level.repeatOnFail ? "Repite el compás si fallas" : "Sigue aunque falles") }
        if level.display == .both { lines.append("Con nombre de nota") }
        lines.append("\(level.sessionLength) ejercicios")
        return lines.joined(separator: "\n")
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
