import SwiftUI

struct RhythmPracticeView: View {
    @Environment(MIDIManager.self) private var midi
    @State private var session: RhythmSession
    @State private var metronome = Metronome()
    @AppStorage("showKeyboard") private var showKeyboard = true

    init(settings: PracticeSettings) {
        _session = State(initialValue: RhythmSession(settings: settings))
    }

    private var s: PracticeSettings { session.settings }

    var body: some View {
        Group {
            if session.isFinished {
                RhythmResultsView(session: session)
            } else {
                practice
            }
        }
        .navigationTitle(session.isFinished ? "Resultados" : "Ritmo")
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
        .sensoryFeedback(.success, trigger: session.streak)
        .onAppear {
            let session = session
            midi.onNoteOn = { note, time in session.noteOn(note, at: time) }
            midi.onNoteOff = { note, time in session.noteOff(note, at: time) }
            metronome.onBeat = { _, time in session.beat(at: time) }
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
        metronome.start(bpm: s.bpm, meter: s.meter, click: s.metronomeClick)
    }

    /// La pista suena alineada con el ejercicio si todavía estás en la cuenta.
    private func playHint() {
        session.useHint()
        let now = RhythmSession.now()
        let delay = max(0, (session.t0 ?? now) - now)
        SoundEngine.shared.play(timed: session.hintNotes, after: delay)
    }

    private var practice: some View {
        VStack(spacing: 14) {
            HStack {
                Label("\(session.score)", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
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

            HStack(spacing: 8) {
                ForEach(0..<s.meter.beats, id: \.self) { i in
                    let accent = s.meter.accents.contains(i)
                    Circle()
                        .fill(metronome.beat == i ? (accent ? Color.orange : Color.accentColor) : Color.gray.opacity(0.25))
                        .frame(width: accent ? 16 : 12, height: accent ? 16 : 12)
                }
                Text("\(s.bpm) BPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if session.attempt > 1 {
                    Text("Intento \(session.attempt)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                if s.sessionLength > 0 {
                    Text("\(min(session.results.count + 1, s.sessionLength))/\(s.sessionLength)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            TimelineView(.animation) { _ in
                let now = RhythmSession.now()
                VStack(spacing: 8) {
                    RhythmStaffView(
                        exercise: session.exercise,
                        colors: session.exercise.events.indices.map { session.color(event: $0) },
                        playhead: session.playheadTick(now: now)
                    )
                    Group {
                        if !session.hasStarted {
                            Text("Escucha el metrónomo…")
                        } else if let beat = session.countInBeat(now: now) {
                            Text("Cuenta: \(beat)")
                        } else {
                            Text("¡Toca!")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.secondary)
                }
            }

            Text(session.message ?? " ")
                .font(.title3.weight(.semibold))
                .foregroundStyle(session.messageColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: 30)

            HStack {
                Text("Verde a tiempo · naranja adelantado/atrasado · rojo fallo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: playHint) {
                    Label(session.hintUsed ? "Otra vez" : "Escuchar (½ pts)", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .font(.subheadline)
            }

            Spacer(minLength: 0)

            if showKeyboard {
                PianoKeyboardView(
                    range: s.exactOctave ? 36...84 : 60...72,
                    naming: s.naming,
                    onPress: { midi in
                        let time = RhythmSession.now()
                        SoundEngine.shared.play([midi], duration: 0.3)
                        session.noteOn(midi, at: time)
                    }
                )
            }
        }
        .padding()
    }
}

struct RhythmResultsView: View {
    let session: RhythmSession

    var body: some View {
        let results = session.results
        let all = results.flatMap(\.judgments)
        let onTime = all.filter(\.isClean).count
        let perfect = all.filter { $0 == .perfect }.count
        let clean = results.filter(\.clean).count

        List {
            Section {
                LabeledContent("Puntaje", value: "\(session.score)")
                LabeledContent("Mejor racha", value: "\(session.bestStreak)")
                LabeledContent("Compases perfectos", value: "\(clean)/\(results.count)")
                LabeledContent("Notas a tiempo", value: all.isEmpty ? "—" : "\(onTime * 100 / all.count)%")
                LabeledContent("Perfectas", value: "\(perfect)")
                LabeledContent("Adelantadas / atrasadas", value: "\(all.filter { $0 == .early }.count) / \(all.filter { $0 == .late }.count)")
                LabeledContent("Equivocadas / no tocadas", value: "\(all.filter { $0 == .wrongNote }.count) / \(all.filter { $0 == .miss }.count)")
                LabeledContent("Soltadas antes", value: "\(all.filter { $0 == .short }.count)")
                LabeledContent("Notas de más", value: "\(results.reduce(0) { $0 + $1.extras })")
            }
            .monospacedDigit()

            if !results.isEmpty {
                Section("Compases") {
                    ForEach(results) { result in
                        HStack(spacing: 8) {
                            Text(result.exercise.clef.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .leading)
                            Text(result.exercise.label(session.settings.naming))
                                .lineLimit(1)
                            if result.usedHint {
                                Image(systemName: "speaker.wave.2.fill").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(result.onTime)/\(result.judgments.count)")
                                .foregroundStyle(result.clean ? .green : .orange)
                            Text("+\(result.points)").foregroundStyle(.yellow)
                        }
                        .monospacedDigit()
                    }
                }
            }

            Section {
                Button { session.restart() } label: {
                    Label("Practicar otra vez", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
