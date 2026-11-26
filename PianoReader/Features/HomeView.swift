import SwiftUI

struct HomeView: View {
    @Environment(MIDIManager.self) private var midi
    @Environment(SettingsStore.self) private var store
    @State private var showBluetooth = false
    @State private var showSettings = false
    @State private var practicing = false
    @State private var practiceID = UUID()
    @AppStorage("bestScore") private var bestScore = 0
    @AppStorage("bestStreak") private var bestStreak = 0

    var body: some View {
        let s = store.settings
        NavigationStack {
            List {
                Section {
                    Button {
                        practiceID = UUID()
                        practicing = true
                    } label: {
                        Label("Empezar", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }

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
                    LabeledContent("Mano", value: s.clef.detail)
                    LabeledContent("Tonalidades", value: s.keysSummary)
                    LabeledContent("Notas y acordes", value: ExerciseKind.selectable.filter { s.kinds.contains($0) }.map(\.label).joined(separator: ", "))
                    LabeledContent("Figuras", value: (["Negras"] + RhythmFeature.allCases.filter { s.rhythmFeatures.contains($0) }.map(\.label)).joined(separator: ", "))
                    LabeledContent("Mostrar", value: s.display.label)
                    LabeledContent("Metrónomo", value: s.metronomeSummary)
                    LabeledContent("Sesión", value: s.sessionLength == 0 ? "Sin límite" : "\(s.sessionLength) ejercicios")
                    Button("Configurar") { showSettings = true }
                }

                Section("Récords") {
                    LabeledContent("Mejor puntaje", value: "\(bestScore)")
                    LabeledContent("Mejor racha", value: "\(bestStreak)")
                }
            }
            .navigationTitle("Lectura de piano")
            .navigationDestination(isPresented: $practicing) {
                // Un id nuevo en cada "Empezar": SwiftUI conservaba la sesión anterior (y sus resultados).
                PracticeView(settings: store.settings)
                    .id(practiceID)
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
