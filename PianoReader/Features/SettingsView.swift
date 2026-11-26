import SwiftUI

struct SettingsView: View {
    @Bindable var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    LevelPickerView(store: store)
                } label: {
                    LabeledContent("Nivel", value: store.settings.levelSummary)
                }
            } footer: {
                Text("Un nivel aplica todos los ajustes de abajo; luego puedes cambiar lo que quieras.")
            }

            Section {
                Picker("Mano", selection: $store.settings.clef) {
                    ForEach(ClefChoice.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if store.settings.clef == .both {
                    Toggle("Izquierda en clave de sol", isOn: $store.settings.leftHandTreble)
                }
                NavigationLink {
                    KeyPickerView(store: store)
                } label: {
                    LabeledContent("Tonalidades", value: store.settings.keysSummary)
                }
            } header: {
                Text("Mano")
            } footer: {
                Text("Derecha: clave de sol. Izquierda: clave de fa. Ambas: pentagrama doble; la derecha lleva la melodía y la izquierda la acompaña (acordes, bajo de Alberti, vals…), como en Czerny Op. 599.")
            }

            Section {
                ForEach(ExerciseKind.selectable) { kind in
                    Toggle(kind.label, isOn: kindBinding(kind))
                }
            } header: {
                Text("Notas y acordes")
            } footer: {
                Text("Cada nota del compás sale suelta, como intervalo o como tríada, al azar entre lo que elijas.")
            }

            Section {
                ForEach(RhythmFeature.allCases) { feature in
                    Toggle(feature.label, isOn: featureBinding(feature))
                }
                Stepper("Compases por ejercicio: \(store.settings.rhythmMeasures)",
                        value: $store.settings.rhythmMeasures, in: 1...2)
            } header: {
                Text("Figuras")
            } footer: {
                Text("Las negras siempre están (en 6/8, la negra con puntillo). Saltillo = corchea con puntillo + semicorchea.")
            }

            Section {
                Picker("Movimiento de la mano", selection: $store.settings.motion) {
                    ForEach(HandMotion.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Líneas adicionales", isOn: $store.settings.ledgerLines)
                Toggle("Alteraciones accidentales (♯ ♭ ♮)", isOn: $store.settings.accidentals)
                Toggle("Octava exacta", isOn: $store.settings.exactOctave)
            } header: {
                Text("Lectura")
            } footer: {
                Text("\(store.settings.motion.detail). Las alteraciones accidentales se apartan de la armadura y duran hasta la barra de compás. Con octava exacta, G4 solo acepta ese G; sin ella, cualquier G sirve.")
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

            Section {
                Toggle("Empezar con metrónomo", isOn: $store.settings.metronome)
                Stepper("Tempo: \(store.settings.bpm) BPM", value: $store.settings.bpm, in: 40...200, step: 5)
                ForEach(Meter.allCases) { meter in
                    Toggle("Compás \(meter.rawValue)", isOn: meterBinding(meter))
                }
                Toggle("Sonido de clic", isOn: $store.settings.metronomeClick)
                Toggle("Repetir el compás si fallas", isOn: $store.settings.repeatOnFail)
            } header: {
                Text("Metrónomo")
            } footer: {
                Text("Con metrónomo se evalúa el ritmo (cuándo empieza y cuánto dura cada nota); sin él tocas las notas en orden a tu ritmo y repites la que falles. Con varios compases, cada ejercicio sale en uno al azar. Se puede cambiar durante la práctica. En 6/8 el clic marca corcheas.")
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

    /// Siempre debe quedar al menos un tipo.
    private func kindBinding(_ kind: ExerciseKind) -> Binding<Bool> {
        Binding(
            get: { store.settings.kinds.contains(kind) },
            set: { on in
                if on {
                    store.settings.kinds.insert(kind)
                } else if store.settings.kinds.filter({ ExerciseKind.selectable.contains($0) }).count > 1 {
                    store.settings.kinds.remove(kind)
                }
            }
        )
    }

    /// Siempre queda al menos un compás; el compás actual sigue siendo uno de los elegidos.
    private func meterBinding(_ meter: Meter) -> Binding<Bool> {
        Binding(
            get: { store.settings.meters.contains(meter) },
            set: { on in
                if on {
                    store.settings.meters.insert(meter)
                } else if store.settings.meters.count > 1 {
                    store.settings.meters.remove(meter)
                }
                if !store.settings.meters.contains(store.settings.meter) {
                    store.settings.meter = Meter.allCases.first { store.settings.meters.contains($0) } ?? .fourFour
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

/// Elegir tonalidades (armaduras). Siempre queda al menos una.
struct KeyPickerView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        List {
            Section {
                Button("Todas") { store.settings.keyFifths = Set(-7...7) }
                Button("Solo Do mayor") { store.settings.keyFifths = [0] }
            }
            Section("Sostenidos") {
                ForEach(KeySignature.all.filter { $0.fifths >= 0 }, id: \.fifths) { row($0) }
            }
            Section("Bemoles") {
                ForEach(Array(KeySignature.all.filter { $0.fifths < 0 }.reversed()), id: \.fifths) { row($0) }
            }
        }
        .navigationTitle("Tonalidades")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ key: KeySignature) -> some View {
        Toggle(isOn: Binding(
            get: { store.settings.keyFifths.contains(key.fifths) },
            set: { on in
                if on {
                    store.settings.keyFifths.insert(key.fifths)
                } else if store.settings.keyFifths.count > 1 {
                    store.settings.keyFifths.remove(key.fifths)
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(key.label)
                Text(key.signLabel).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
