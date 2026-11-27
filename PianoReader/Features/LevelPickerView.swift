import SwiftUI

/// Cargar los ajustes de un nivel en la práctica libre (menos el nombre de las notas).
struct LevelPickerView: View {
    @Bindable var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(Level.ordered) { level in
            Button {
                level.apply(to: &store.settings)
                dismiss()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(level.position)")

                        .font(.title3.bold().monospacedDigit())
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(level.title).font(.headline).foregroundStyle(.primary)
                        Text(level.summary)
                        Text(level.details.joined(separator: "\n"))
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
        .navigationTitle("Ajustes de un nivel")
        .navigationBarTitleDisplayMode(.inline)
    }
}
