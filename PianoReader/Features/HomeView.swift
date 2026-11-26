import SwiftUI

struct HomeView: View {
    @Environment(MIDIManager.self) private var midi
    @Environment(SettingsStore.self) private var store
    @State private var showBluetooth = false
    @State private var showSettings = false
    @State private var practicing = false
    @AppStorage("bestScore") private var bestScore = 0
    @AppStorage("bestStreak") private var bestStreak = 0
    @AppStorage("rhythmBestScore") private var rhythmBestScore = 0
    @AppStorage("rhythmBestStreak") private var rhythmBestStreak = 0

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

                Section("Práctica") {
                    LabeledContent("Modo", value: s.mode.label)
                    LabeledContent("Clave", value: s.clef.label)
                    if s.mode == .rhythm {
                        LabeledContent("Figuras", value: (["Negras"] + RhythmFeature.allCases.filter { s.rhythmFeatures.contains($0) }.map(\.label)).joined(separator: ", "))
                        LabeledContent("Metrónomo", value: "\(s.bpm) BPM · \(s.meter.rawValue)")
                    } else {
                        LabeledContent("Ejercicios", value: ExerciseKind.allCases.filter { s.kinds.contains($0) }.map(\.label).joined(separator: ", "))
                        LabeledContent("Mostrar", value: s.display.label)
                        LabeledContent("Metrónomo", value: s.metronomeSummary)
                    }
                    LabeledContent("Sesión", value: s.sessionLength == 0 ? "Sin límite" : "\(s.sessionLength) ejercicios")
                    Button("Configurar") { showSettings = true }
                }

                Section("Récords") {
                    LabeledContent("Notas", value: "\(bestScore) pts · racha \(bestStreak)")
                    LabeledContent("Ritmo", value: "\(rhythmBestScore) pts · racha \(rhythmBestStreak)")
                }

                Section {
                    Button { practicing = true } label: {
                        Label("Empezar", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Lectura de piano")
            .navigationDestination(isPresented: $practicing) {
                if store.settings.mode == .rhythm {
                    RhythmPracticeView(settings: store.settings)
                } else {
                    PracticeView(settings: store.settings)
                }
            }
            .sheet(isPresented: $showBluetooth) {
                BluetoothMIDIView()
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView(store: store) }
            }
        }
    }
}
