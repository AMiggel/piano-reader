import SwiftUI

struct ResultsView: View {
    let session: PracticeSession

    var body: some View {
        let results = session.results
        let s = session.settings
        let firstTry = results.filter { $0.errors == 0 && !$0.timedOut }.count
        let timedOut = results.filter(\.timedOut).count
        let hints = results.filter(\.usedHint).count
        let total = (session.finishedAt ?? Date()).timeIntervalSince(session.sessionStartedAt)

        List {
            Section {
                row("Puntaje", "\(session.score)")
                row("Mejor racha", "\(session.bestStreak)")
                row("Correctas", "\(results.count - timedOut)")
                row("Fallos", "\(results.reduce(0) { $0 + $1.errors })")
                if s.metronome { row("Sin tiempo", "\(timedOut)") }
                if hints > 0 { row("Con pista", "\(hints)") }
                row("A la primera", results.isEmpty ? "—" : "\(firstTry * 100 / results.count)%")
                row("Tiempo promedio", session.averageTime.map(seconds) ?? "—")
                row("Tiempo total", seconds(total))
            }

            let slowest = results.filter { !$0.timedOut }.sorted { $0.time > $1.time }.prefix(5)
            if !slowest.isEmpty {
                Section("Más lentas") {
                    ForEach(slowest) { resultRow($0, s) }
                }
            }

            let failed = results.filter { $0.errors > 0 || $0.timedOut }.sorted { $0.errors > $1.errors }
            if !failed.isEmpty {
                Section("Con fallos") {
                    ForEach(failed) { resultRow($0, s) }
                }
            }

            if !results.isEmpty {
                Section("Todas") {
                    ForEach(results) { resultRow($0, s) }
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

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value).monospacedDigit()
    }

    private func resultRow(_ result: ExerciseResult, _ s: PracticeSettings) -> some View {
        HStack(spacing: 8) {
            Text(result.exercise.clef.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            Text(result.exercise.label(s.naming, octave: s.exactOctave))
            if result.usedHint {
                Image(systemName: "speaker.wave.2.fill").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if result.errors > 0 {
                Text("\(result.errors) ✕").foregroundStyle(.red)
            }
            if result.timedOut {
                Image(systemName: "timer").foregroundStyle(.orange)
            } else {
                Text("+\(result.points)").foregroundStyle(.yellow)
            }
            Text(seconds(result.time)).foregroundStyle(.secondary)
        }
        .monospacedDigit()
    }

    private func seconds(_ t: TimeInterval) -> String {
        String(format: "%.1f s", t)
    }
}
