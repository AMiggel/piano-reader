import SwiftUI

struct PracticeView: View {
    @Environment(MIDIManager.self) private var midi
    @State private var session: PracticeSession
    @State private var metronome = Metronome()
    @AppStorage("showKeyboard") private var showKeyboard = true

    init(settings: PracticeSettings) {
        _session = State(initialValue: PracticeSession(settings: settings))
    }

    private var s: PracticeSettings { session.settings }

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
            midi.onNoteOn = { note, _ in session.noteOn(note) }
            midi.onNoteOff = { note, _ in session.noteOff(note) }
            metronome.onBeat = { _, _ in session.beat() }
            startMetronome()
        }
        .onDisappear {
            midi.onNoteOn = nil
            midi.onNoteOff = nil
            metronome.stop()
        }
        .onChange(of: session.isFinished) { _, finished in
            if finished { metronome.stop() } else { startMetronome() }
        }
    }

    private func startMetronome() {
        guard s.metronome else { return }
        metronome.start(bpm: s.bpm, meter: s.meter, click: s.metronomeClick)
    }

    private func playHint() {
        session.useHint()
        let sequence = session.exercise.steps.map { $0.map(\.midi) }
        if sequence.count == 1 {
            SoundEngine.shared.play(sequence[0], duration: 1.2)
        } else {
            SoundEngine.shared.play(sequence: sequence, gap: s.metronome ? 60 / Double(s.bpm) : 0.6)
        }
    }

    // MARK: - Vistas

    private var practice: some View {
        VStack(spacing: 14) {
            scoreBar
            statsBar

            if s.metronome { beatBar }

            if session.isWaitingStart {
                countIn
            } else {
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
            }

            HStack {
                if session.exercise.steps.count > 1 && !session.isWaitingStart {
                    Text("Nota \(session.stepIndex + 1) de \(session.exercise.steps.count)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: playHint) {
                    Label(session.hintUsed ? "Escuchar otra vez" : "Escuchar (½ pts)",
                          systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!session.acceptsInput)
            }
            .font(.subheadline)

            feedbackLine
                .font(.title3.weight(.semibold))
                .frame(height: 32)

            Spacer(minLength: 0)

            if showKeyboard {
                PianoKeyboardView(
                    naming: s.naming,
                    follow: s.exactOctave ? session.exercise.steps[session.stepIndex].first?.midi : nil,
                    onPress: { midi in
                        SoundEngine.shared.play([midi], duration: 0.5)
                        session.noteOn(midi)
                    }
                )
            }
        }
        .padding()
    }

    private var scoreBar: some View {
        HStack {
            Label("\(session.score)", systemImage: "star.fill")
                .foregroundStyle(.yellow)
                .contentTransition(.numericText())
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(session.streak > 0 ? .orange : .gray)
                Text("\(session.streak)")
                if session.multiplier > 1 {
                    Text("×\(session.multiplier)")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.orange.opacity(0.2)))
                }
            }
        }
        .font(.title2.weight(.bold))
        .monospacedDigit()
        .animation(.default, value: session.score)
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            Label("\(session.results.filter { !$0.timedOut }.count)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Label("\(session.totalErrors)", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
            Spacer()
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                Label(String(format: "%.1f s", session.elapsed), systemImage: "timer")
            }
            if s.sessionLength > 0 {
                Text("\(min(session.results.count + 1, s.sessionLength))/\(s.sessionLength)")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.headline)
        .monospacedDigit()
    }

    /// Puntos del compás + tiempos que quedan.
    private var beatBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<s.meter.beats, id: \.self) { i in
                let accent = s.meter.accents.contains(i)
                Circle()
                    .fill(metronome.beat == i ? (accent ? Color.orange : Color.accentColor) : Color.gray.opacity(0.25))
                    .frame(width: accent ? 16 : 12, height: accent ? 16 : 12)
            }
            Text("\(s.bpm) BPM · \(s.meter.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !session.isWaitingStart {
                Text("Quedan \(max(session.beatsLeft, 0)) tiempos")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(session.beatsLeft <= 1 ? Color.red : Color.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var countIn: some View {
        VStack(spacing: 8) {
            Text("Prepárate")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(session.countInBeat > 0 ? "\(session.countInBeat)" : "")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
    }

    @ViewBuilder
    private var feedbackLine: some View {
        let played = session.lastPlayed.map { Note.pitchName(midi: $0, style: s.naming, octave: s.exactOctave) }
        switch session.feedback {
        case .correct:
            Label("¡Correcto! +\(session.lastPoints)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .wrong:
            Label("Tocaste \(played ?? "?"), otra vez", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .timeout:
            Label("¡Se acabó el tiempo!", systemImage: "timer")
                .foregroundStyle(.orange)
        case .none:
            if let played {
                Text("Tocaste: \(played)").foregroundStyle(.secondary)
            } else {
                Text("Toca la nota en tu piano").foregroundStyle(.secondary)
            }
        }
    }
}
