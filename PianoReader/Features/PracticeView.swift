import SwiftUI

struct PracticeView: View {
    @Environment(MIDIManager.self) private var midi
    @State private var session: PracticeSession
    @AppStorage("showKeyboard") private var showKeyboard = true

    init(settings: PracticeSettings) {
        _session = State(initialValue: PracticeSession(settings: settings))
    }

    var body: some View {
        Group {
            if session.isFinished {
                ResultsView(session: session)
            } else {
                practice
            }
        }
        .navigationTitle(session.isFinished ? "Resultados" : "Práctica")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !session.isFinished {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showKeyboard.toggle() } label: {
                        Image(systemName: showKeyboard ? "pianokeys.inverse" : "pianokeys")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Terminar") { session.finish() }
                }
            }
        }
        .sensoryFeedback(.error, trigger: session.totalErrors)
        .sensoryFeedback(.success, trigger: session.results.count)
        .onAppear {
            let session = session
            midi.onNoteOn = { session.noteOn($0) }
            midi.onNoteOff = { session.noteOff($0) }
        }
        .onDisappear {
            midi.onNoteOn = nil
            midi.onNoteOff = nil
        }
    }

    private var practice: some View {
        let s = session.settings
        return VStack(spacing: 16) {
            statsBar

            if s.display != .name {
                HStack {
                    Text("Clave de \(session.exercise.clef.label.lowercased())")
                    Spacer()
                    Text(session.exercise.kind.label)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                StaffView(session: session)
            }
            if s.display != .staff {
                NoteNameView(session: session)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }

            if session.exercise.steps.count > 1 {
                Text("Nota \(session.stepIndex + 1) de \(session.exercise.steps.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            feedbackLine
                .font(.title3.weight(.semibold))
                .frame(height: 32)

            Spacer(minLength: 0)

            if showKeyboard {
                PianoKeyboardView(
                    range: s.exactOctave ? 36...84 : 60...72,
                    naming: s.naming,
                    onPress: { session.noteOn($0) }
                )
            }
        }
        .padding()
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            Label("\(session.results.count)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Label("\(session.totalErrors)", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
            if session.currentErrors > 0 {
                Text("(\(session.currentErrors) en esta)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                Label(String(format: "%.1f s", session.elapsed), systemImage: "timer")
                    .monospacedDigit()
            }
            if session.settings.sessionLength > 0 {
                Text("\(min(session.results.count + 1, session.settings.sessionLength))/\(session.settings.sessionLength)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .font(.headline)
    }

    @ViewBuilder
    private var feedbackLine: some View {
        let s = session.settings
        let played = session.lastPlayed.map { Note.pitchName(midi: $0, style: s.naming, octave: s.exactOctave) }
        switch session.feedback {
        case .correct:
            Label("¡Correcto!", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .wrong:
            Label("Tocaste \(played ?? "?"), otra vez", systemImage: "xmark.circle.fill").foregroundStyle(.red)
        case .none:
            if let played {
                Text("Tocaste: \(played)").foregroundStyle(.secondary)
            } else {
                Text("Toca la nota en tu piano").foregroundStyle(.secondary)
            }
        }
    }
}
