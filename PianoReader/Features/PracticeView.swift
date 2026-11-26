import SwiftUI

struct PracticeView: View {
    @Environment(MIDIManager.self) private var midi
    @Environment(SettingsStore.self) private var store
    @State private var session: PracticeSession
    @State private var metronome = Metronome()
    @State private var showTempo = false
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
                    Button {
                        session.setMetronome(!session.metronomeOn)
                        if session.metronomeOn { startMetronome() } else { metronome.stop() }
                    } label: {
                        Image(systemName: session.metronomeOn ? "metronome.fill" : "metronome")
                    }
                    .accessibilityLabel(session.metronomeOn ? "Apagar metrónomo" : "Encender metrónomo")
                }
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
        .sheet(isPresented: $showTempo) {
            TempoSheet(bpm: session.bpm, meter: s.meter) { value, meter in
                session.setTempo(value)
                session.setMeter(meter) // compás distinto = ejercicio nuevo
                store.settings.bpm = value
                store.settings.meter = meter
                startMetronome() // vuelve a empezar con la cuenta
            }
        }
    }

    private func startMetronome() {
        guard session.metronomeOn else { return }
        metronome.start(bpm: session.bpm, meter: s.meter, click: s.metronomeClick)
    }

    /// Con metrónomo y en la cuenta, la pista suena alineada con el compás.
    private func playHint() {
        session.useHint()
        let now = PracticeSession.now()
        let delay = session.metronomeOn ? max(0, (session.t0 ?? now) - now) : 0
        SoundEngine.shared.play(timed: session.hintNotes, after: delay)
    }

    /// Teclas presionadas, escritas en la tonalidad, en su pentagrama.
    /// Con octava exacta van donde suenan (dos manos: desde C4 arriba en sol, abajo en fa);
    /// sin ella, junto a la nota pedida con el mismo nombre (o la más cercana).
    private var ghosts: [(voice: Int, note: Note)] {
        let ex = session.exercise
        let targets = session.currentNotes
        return midi.pressed.sorted().map { m in
            let note = ex.key.spell(midi: m)
            if s.exactOctave {
                let voice = ex.voices.count > 1 && m < 60 ? 1 : 0
                return (voice: voice, note: note)
            }
            if let same = targets.first(where: { ($0.note.midi - m) % 12 == 0 }) {
                return (voice: same.voice, note: note.folded(near: same.note.diatonic))
            }
            let target = targets.first ?? (voice: 0, note: Note(diatonic: ex.voices[0].clef.bottomLine + 4))
            return (voice: target.voice, note: note.folded(near: target.note.diatonic))
        }
    }

    private var playedName: String? {
        let held = midi.pressed.sorted()
        let notes = held.isEmpty ? (midi.lastNote.map { [$0] } ?? []) : held
        guard !notes.isEmpty else { return nil }
        return notes.map { session.exercise.key.spell(midi: $0).name(s.naming, octave: true) }.joined(separator: " ")
    }

    // MARK: - Vistas

    private var practice: some View {
        VStack(spacing: 12) {
            scoreBar
            infoBar

            TimelineView(.animation(paused: !session.metronomeOn)) { _ in
                let now = PracticeSession.now()
                VStack(spacing: 8) {
                    if s.display != .name {
                        RhythmStaffView(
                            exercise: session.exercise,
                            colors: session.exercise.voices.indices.map { v in
                                session.exercise.voices[v].events.indices.map { session.color(voice: v, index: $0) }
                            },
                            playhead: session.playheadTick(now: now),
                            ghosts: ghosts
                        )
                    }
                    if s.display != .staff {
                        NoteNamesView(session: session)
                    }
                    HStack {
                        Group {
                            if !session.metronomeOn {
                                Text("A tu ritmo")
                            } else if !session.hasStarted {
                                Text("Escucha el metrónomo…")
                            } else if let beat = session.countInBeat(now: now) {
                                Text("Cuenta: \(beat)")
                            } else {
                                Text("¡Toca!")
                            }
                        }
                        Spacer()
                        if let played = playedName {
                            Text("Tocaste: \(played)").foregroundStyle(.blue)
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
                Text(session.metronomeOn
                     ? "Verde a tiempo · naranja adelantado/atrasado · rojo fallo"
                     : "Verde a la primera · naranja tras fallar · rojo fallo")
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
                    naming: s.naming,
                    follow: s.exactOctave ? session.currentOnset?.midis.first : nil,
                    highlighted: midi.pressed,
                    onPress: { note in
                        let time = PracticeSession.now()
                        midi.flash(note)
                        SoundEngine.shared.play([note], duration: 0.4)
                        session.noteOn(note, at: time)
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

    private var infoBar: some View {
        HStack(spacing: 8) {
            if session.metronomeOn {
                ForEach(0..<s.meter.beats, id: \.self) { i in
                    let accent = s.meter.accents.contains(i)
                    Circle()
                        .fill(metronome.beat == i ? (accent ? Color.orange : Color.accentColor) : Color.gray.opacity(0.25))
                        .frame(width: accent ? 16 : 12, height: accent ? 16 : 12)
                }
            }
            Button { showTempo = true } label: {
                Label("\(session.bpm) BPM · \(s.meter.rawValue)", systemImage: "metronome")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            Text("\(session.exercise.key.majorName) M")
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
    }
}

/// Modo "Nombre": G  D  C-E-G  B… con el color de cada nota; la actual subrayada.
struct NoteNamesView: View {
    let session: PracticeSession

    var body: some View {
        let s = session.settings
        let voices = session.exercise.voices
        let current = session.currentIndex
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                // Cada momento: sus notas (de las dos manos) de aguda a grave, p. ej. "E-C".
                ForEach(session.onsets.indices, id: \.self) { i in
                    let refs = session.onsets[i].refs
                    let notes = refs.flatMap { voices[$0.voice].events[$0.index].notes }.sorted { $0.midi > $1.midi }
                    Text(notes.map { $0.name(s.naming, octave: s.exactOctave) }.joined(separator: "-"))
                        .foregroundStyle(refs.first.flatMap { session.color(voice: $0.voice, index: $0.index) } ?? .primary)
                        .underline(i == current)
                }
            }
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .padding(.horizontal, 4)
        }
        .frame(height: 50)
    }
}

struct ResultsView: View {
    let session: PracticeSession

    var body: some View {
        let results = session.results
        let timed = results.filter(\.timed)
        let all = timed.flatMap(\.judgments)
        let onTime = all.filter(\.isClean).count
        let free = results.compactMap(\.secondsPerNote)
        let clean = results.filter(\.clean).count
        let failures = results.reduce(0) { total, result in
            total + result.errors + result.judgments.filter { [.wrongNote, .miss, .short, .retried].contains($0) }.count
        }

        List {
            Section {
                LabeledContent("Puntaje", value: "\(session.score)")
                LabeledContent("Mejor racha", value: "\(session.bestStreak)")
                LabeledContent("Ejercicios perfectos", value: "\(clean)/\(results.count)")
                LabeledContent("Fallos", value: "\(failures)")
                if !free.isEmpty {
                    LabeledContent("Tiempo por nota", value: String(format: "%.1f s", free.reduce(0, +) / Double(free.count)))
                }
                if !all.isEmpty {
                    LabeledContent("Notas a tiempo", value: "\(onTime * 100 / all.count)%")
                    LabeledContent("Adelantadas / atrasadas", value: "\(all.filter { $0 == .early }.count) / \(all.filter { $0 == .late }.count)")
                    LabeledContent("Soltadas antes", value: "\(all.filter { $0 == .short }.count)")
                }
            }
            .monospacedDigit()

            if !results.isEmpty {
                Section("Ejercicios") {
                    ForEach(results) { result in
                        HStack(spacing: 8) {
                            Text(result.exercise.clefLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .leading)
                            Text(result.exercise.label(session.settings.naming))
                                .lineLimit(1)
                            if result.usedHint {
                                Image(systemName: "speaker.wave.2.fill").font(.caption).foregroundStyle(.secondary)
                            }
                            if result.timed {
                                Image(systemName: "metronome").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if result.timed {
                                Text("\(result.onTime)/\(result.judgments.count)")
                                    .foregroundStyle(result.clean ? .green : .orange)
                            } else if result.errors > 0 {
                                Text("\(result.errors) ✕").foregroundStyle(.red)
                            }
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
