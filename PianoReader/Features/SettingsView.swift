import SwiftUI

struct SettingsView: View {
    @Bindable var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Clave") {
                Picker("Clave", selection: $store.settings.clef) {
                    ForEach(ClefChoice.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                ForEach(ExerciseKind.allCases) { kind in
                    Toggle(kind.label, isOn: binding(for: kind))
                }
                if store.settings.kinds.contains(.progression) {
                    Stepper("Notas por progresión: \(store.settings.progressionLength)",
                            value: $store.settings.progressionLength, in: 2...5)
                }
            } header: {
                Text("Ejercicios")
            } footer: {
                Text("Si eliges varios, se mezclan al azar.")
            }

            Section {
                Toggle("Líneas adicionales", isOn: $store.settings.ledgerLines)
                Toggle("Sostenidos y bemoles", isOn: $store.settings.accidentals)
                Toggle("Octava exacta", isOn: $store.settings.exactOctave)
            } header: {
                Text("Notas")
            } footer: {
                Text("Sostenidos y bemoles aplican a notas sueltas y progresiones. Con octava exacta, G4 solo acepta ese G; sin ella, cualquier G sirve.")
            }

            Section("Mostrar") {
                Picker("Mostrar", selection: $store.settings.display) {
                    ForEach(DisplayMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Nombres", selection: $store.settings.naming) {
                    ForEach(NamingStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Sesión") {
                Picker("Ejercicios por sesión", selection: $store.settings.sessionLength) {
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("50").tag(50)
                    Text("Sin límite").tag(0)
                }
            }
        }
        .navigationTitle("Configuración")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Listo") { dismiss() }
            }
        }
    }

    /// Siempre debe quedar al menos un tipo de ejercicio.
    private func binding(for kind: ExerciseKind) -> Binding<Bool> {
        Binding(
            get: { store.settings.kinds.contains(kind) },
            set: { on in
                if on {
                    store.settings.kinds.insert(kind)
                } else if store.settings.kinds.count > 1 {
                    store.settings.kinds.remove(kind)
                }
            }
        )
    }
}
