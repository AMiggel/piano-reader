import SwiftUI

/// Toda la configuración en un solo lugar: piano, práctica libre, ajustes, récords y progreso.
struct ConfigView: View {
    let onStartFree: () -> Void
    @Environment(MIDIManager.self) private var midi
    @Environment(SettingsStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var showBluetooth = false
    @State private var confirmReset = false
    @AppStorage("bestScore") private var bestScore = 0
    @AppStorage("bestStreak") private var bestStreak = 0

    var body: some View {
        let s = store.settings
        NavigationStack {
            List {
                Section("Piano") {
                    if midi.sources.isEmpty {
                        Label("Sin piano conectado", systemImage: "pianokeys")
                            .foregroundStyle(.secondary)
                        Text("Conéctalo por USB (adaptador) o Bluetooth MIDI. También puedes usar el teclado en pantalla.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(midi.sources, id: \.self) { name in
                            Label(name, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                    Button { showBluetooth = true } label: {
                        Label("Conectar por Bluetooth", systemImage: "dot.radiowaves.left.and.right")
                    }
                    Button { midi.refresh() } label: {
                        Label("Buscar de nuevo", systemImage: "arrow.clockwise")
                    }
                }

                Section {
                    Button(action: onStartFree) {
                        Label("Empezar práctica libre", systemImage: "play.fill")
                            .font(.headline)
                    }
                    NavigationLink {
                        SettingsView(store: store)
                    } label: {
                        Label("Ajustes de la práctica libre", systemImage: "slider.horizontal.3")
                    }
                    LabeledContent("Basado en", value: s.levelSummary)
                    LabeledContent("Mano", value: s.rhythmOnly ? "Solo ritmo (cualquier tecla)" : s.clef.detail)

                    LabeledContent("Movimiento", value: s.motion.label)
                    LabeledContent("Tonalidades", value: s.keysSummary)
                    LabeledContent("Notas y acordes", value: ExerciseKind.selectable.filter { s.kinds.contains($0) }.map(\.label).joined(separator: ", "))
                    LabeledContent("Figuras", value: (["Negras"] + RhythmFeature.allCases.filter { s.rhythmFeatures.contains($0) }.map(\.label)).joined(separator: ", "))
                    LabeledContent("Mostrar", value: s.display.label)
                    LabeledContent("Metrónomo", value: s.metronomeSummary)
                    LabeledContent("Sesión", value: s.sessionLength == 0 ? "Sin límite" : "\(s.sessionLength) ejercicios")
                } header: {
                    Text("Práctica libre")
                } footer: {
                    Text("Practica con tus propios ajustes, sin estrellas. En los niveles se usan los ajustes de cada nivel; el nombre de las notas (C D E o Do Re Mi) se toma de aquí.")
                }

                Section("Nombres de las notas") {
                    Picker("Nombres", selection: Binding(get: { store.settings.naming }, set: { store.settings.naming = $0 })) {
                        ForEach(NamingStyle.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Sonido de clic del metrónomo", isOn: Binding(get: { store.settings.metronomeClick },
                                                                         set: { store.settings.metronomeClick = $0 }))
                }

                Section("Récords") {
                    LabeledContent("Mejor puntaje", value: "\(bestScore)")
                    LabeledContent("Mejor racha", value: "\(bestStreak)")
                    LabeledContent("Estrellas", value: "\(progress.totalStars)/\(progress.maxStars)")
                }

                Section {
                    Button("Reiniciar progreso de niveles", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .sheet(isPresented: $showBluetooth) {
                BluetoothMIDIView()
            }
            .confirmationDialog("¿Borrar todas las estrellas y volver a bloquear los niveles?",
                                isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reiniciar", role: .destructive) { progress.reset() }
            }
        }
    }
}
