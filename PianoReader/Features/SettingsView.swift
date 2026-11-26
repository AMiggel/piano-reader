import SwiftUI

struct SettingsView: View {
    @Bindable var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    private var isRhythm: Bool { store.settings.mode == .rhythm }

    var body: some View {
        Form {
            Section {
                Picker("Modo", selection: $store.settings.mode) {
                    ForEach(PracticeMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(isRhythm
                     ? "Ritmo: lees un compás con figuras y lo tocas a tiempo con el metrónomo. Necesita el piano por MIDI para medir bien."
                     : "Notas: lees notas, intervalos, tríadas o progresiones y las tocas.")
            }

            Section("Clave") {
                Picker("Clave", selection: $store.settings.clef) {
                    ForEach(ClefChoice.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if isRhythm {
                Section {
                    ForEach(RhythmFeature.allCases) { feature in
                        Toggle(feature.label, isOn: featureBinding(feature))
                    }
                    Stepper("Compases por ejercicio: \(store.settings.rhythmMeasures)",
                            value: $store.settings.rhythmMeasures, in: 1...2)
                    Toggle("Repetir el compás si fallas", isOn: $store.settings.repeatOnFail)
                } header: {
                    Text("Figuras")
                } footer: {
                    Text("Las negras siempre están (en 6/8, la negra con puntillo). Saltillo = corchea con puntillo + semicorchea.")
                }
            } else {
                Section {
                    ForEach(ExerciseKind.allCases) { kind in
                        Toggle(kind.label, isOn: kindBinding(kind))
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
            }

            Section {
                Toggle("Líneas adicionales", isOn: $store.settings.ledgerLines)
                if !isRhythm {
                    Toggle("Sostenidos y bemoles", isOn: $store.settings.accidentals)
                }
                Toggle("Octava exacta", isOn: $store.settings.exactOctave)
            } header: {
                Text("Notas")
            } footer: {
                Text("Con octava exacta, G4 solo acepta ese G; sin ella, cualquier G sirve.")
            }

            if !isRhythm {
                Section("Mostrar") {
                    Picker("Mostrar", selection: $store.settings.display) {
                        ForEach(DisplayMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section("Nombres") {
                Picker("Nombres", selection: $store.settings.naming) {
                    ForEach(NamingStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                if !isRhythm {
                    Toggle("Usar metrónomo", isOn: $store.settings.metronome)
                }
                if isRhythm || store.settings.metronome {
                    Stepper("Tempo: \(store.settings.bpm) BPM", value: $store.settings.bpm, in: 40...200, step: 5)
                    Picker("Compás", selection: $store.settings.meter) {
                        ForEach(Meter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if !isRhythm {
                        Picker("Tiempo por nota", selection: $store.settings.window) {
                            ForEach(BeatWindow.allCases) { Text($0.label).tag($0) }
                        }
                    }
                    Toggle("Sonido de clic", isOn: $store.settings.metronomeClick)
                }
            } header: {
                Text("Metrónomo")
            } footer: {
                Text(isRhythm
                     ? "En 6/8 el clic marca corcheas. Más tempo da más puntos."
                     : "Cada nota o acorde se debe tocar dentro del tiempo elegido; si no, cuenta como sin tiempo y pasa al siguiente. Más tempo y menos tiempo por nota dan más puntos.")
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
    private func kindBinding(_ kind: ExerciseKind) -> Binding<Bool> {
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

    private func featureBinding(_ feature: RhythmFeature) -> Binding<Bool> {
        Binding(
            get: { store.settings.rhythmFeatures.contains(feature) },
            set: { on in
                if on {
                    store.settings.rhythmFeatures.insert(feature)
                } else {
                    store.settings.rhythmFeatures.remove(feature)
                }
            }
        )
    }
}
