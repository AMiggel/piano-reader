import SwiftUI

/// Mapa de niveles: se empieza por el 1 y cada nivel con al menos una estrella desbloquea el siguiente.
/// Todo lo demás (piano, práctica libre, ajustes, récords) está en el botón de configuración.
struct HomeView: View {
    @Environment(MIDIManager.self) private var midi
    @Environment(SettingsStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @State private var selected: Level?
    @State private var showConfig = false
    /// Lo que se abre cuando se cierra la hoja (nivel o práctica libre).
    @State private var pending: Start?
    @State private var started: Start?

    struct Start: Identifiable, Hashable {
        let id = UUID()
        let level: Int?
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        header
                            .padding(.bottom, 24)
                        ForEach(Array(Level.all.enumerated()), id: \.element.id) { index, level in
                            if index > 0 { connector(from: index - 1, to: index) }
                            node(level, index: index)
                                .id(level.number)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 24)
                }
                .onAppear { proxy.scrollTo(progress.currentLevel, anchor: .center) }
            }
            .navigationTitle("Lectura de piano")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "pianokeys")
                        .foregroundStyle(midi.sources.isEmpty ? Color.secondary : Color.green)
                        .accessibilityLabel(midi.sources.isEmpty ? "Sin piano conectado" : "Piano conectado")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showConfig = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Configuración")
                }
            }
            .navigationDestination(item: $started) { start in
                if let number = start.level, let level = Level.number(number) {
                    PracticeView(settings: level.settings(from: store.settings), level: number)
                        .id(start.id)
                } else {
                    PracticeView(settings: store.settings)
                        .id(start.id)
                }
            }
            .sheet(item: $selected, onDismiss: launchPending) { level in
                LevelSheet(level: level) {
                    pending = Start(level: level.number)
                    selected = nil
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showConfig, onDismiss: launchPending) {
                ConfigView {
                    pending = Start(level: nil)
                    showConfig = false
                }
            }
        }
    }

    private func launchPending() {
        guard let pending else { return }
        self.pending = nil
        started = pending
    }

    // MARK: - Partes

    private var header: some View {
        let current = Level.number(progress.currentLevel) ?? Level.all[0]
        return VStack(spacing: 10) {
            HStack {
                Label("\(progress.totalStars)/\(Level.all.count * 3)", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline.bold().monospacedDigit())
                Spacer()
                Text(midi.sources.isEmpty ? "Teclado en pantalla" : midi.sources.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Nivel \(current.number)").font(.caption.bold()).foregroundStyle(.white.opacity(0.8))
                Text(current.title).font(.title2.bold()).foregroundStyle(.white)
                Text(current.summary).font(.caption).foregroundStyle(.white.opacity(0.85))
                Button {
                    pending = nil
                    started = Start(level: current.number)
                } label: {
                    Label(progress.stars(for: current.number) > 0 ? "Practicar" : "Continuar", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.top, 8)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color.accentColor, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20)
            )
        }
    }

    /// Zigzag: centro, derecha, centro, izquierda…
    private func xOffset(_ index: Int) -> CGFloat {
        [0, 70, 0, -70][index % 4]
    }

    private func connector(from a: Int, to b: Int) -> some View {
        let unlocked = progress.isUnlocked(Level.all[b].number)
        return VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(unlocked ? Color.accentColor.opacity(0.6) : Color.gray.opacity(0.3))
                    .frame(width: 7, height: 7)
                    .offset(x: xOffset(a) + (xOffset(b) - xOffset(a)) * CGFloat(i + 1) / 4)
            }
        }
        .padding(.vertical, 6)
    }

    private func node(_ level: Level, index: Int) -> some View {
        let unlocked = progress.isUnlocked(level.number)
        let stars = progress.stars(for: level.number)
        let current = level.number == progress.currentLevel
        let size: CGFloat = current ? 88 : 72

        return Button { selected = level } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(fill(unlocked: unlocked, done: stars > 0, current: current))
                        .frame(width: size, height: size)
                        .shadow(color: .black.opacity(unlocked ? 0.2 : 0), radius: 4, y: 3)
                    if current {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.35), lineWidth: 6)
                            .frame(width: size + 14, height: size + 14)
                    }
                    if unlocked {
                        Text("\(level.number)")
                            .font(.system(size: current ? 34 : 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                StarsView(count: stars, size: 14)
                    .opacity(unlocked ? 1 : 0.3)
                Text(level.title)
                    .font(.caption.weight(current ? .bold : .regular))
                    .foregroundStyle(unlocked ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 140)
            }
        }
        .buttonStyle(.plain)
        .offset(x: xOffset(index))
    }

    private func fill(unlocked: Bool, done: Bool, current: Bool) -> LinearGradient {
        let colors: [Color] = if !unlocked {
            [Color.gray.opacity(0.45), Color.gray.opacity(0.6)]
        } else if done {
            [Color.green, Color.teal]
        } else {
            [Color.accentColor, Color.purple]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Level: Hashable {
    static func == (a: Level, b: Level) -> Bool { a.number == b.number }
    func hash(into hasher: inout Hasher) { hasher.combine(number) }
}

struct StarsView: View {
    let count: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i < count ? Color.yellow : Color.gray.opacity(0.5))
            }
        }
        .accessibilityLabel("\(count) de 3 estrellas")
    }
}

/// Detalle de un nivel antes de empezar.
struct LevelSheet: View {
    let level: Level
    let onStart: () -> Void
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        let unlocked = progress.isUnlocked(level.number)
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Text(level.title).font(.title2.bold())
                        StarsView(count: progress.stars(for: level.number), size: 26)
                        Text(level.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                Section("Incluye") {
                    ForEach(level.details, id: \.self) { Text($0) }
                }
                Section {
                    if unlocked {
                        Button(action: onStart) {
                            Label("Empezar", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        Label("Consigue al menos una estrella en el nivel \(level.number - 1) para desbloquearlo.",
                              systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text(ProgressStore.passText)
                }
            }
            .navigationTitle("Nivel \(level.number)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
