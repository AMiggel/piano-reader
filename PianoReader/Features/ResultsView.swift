import SwiftUI

struct ResultsView: View {
    let session: PracticeSession

    var body: some View {
        let results = session.results
        let s = session.settings
        let firstTry = results.filter { $0.errors == 0 }.count
        let total = (session.finishedAt ?? Date()).timeIntervalSince(session.sessionStartedAt)

        List {
            Section {
                row("Correctas", "\(results.count)")
                row("Fallos", "\(results.reduce(0) { $0 + $1.errors })")
                row("A la primera", results.isEmpty ? "—" : "\(firstTry * 100 / results.count)%")
                row("Tiempo promedio", session.averageTime.map(seconds) ?? "—")
                row("Más rápida", results.map(\.time).min().map(seconds) ?? "—")
                row("Tiempo total", seconds(total))
            }

            let slowest = results.sorted { $0.time > $1.time }.prefix(5)
            if !slowest.isEmpty {
                Section("Más lentas") {
                    ForEach(slowest) { resultRow($0, s) }
                }
            }

            let failed = results.filter { $0.errors > 0 }.sorted { $0.errors > $1.errors }
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
        HStack {
            Text(result.exercise.clef.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            Text(result.exercise.label(s.naming, octave: s.exactOctave))
            Spacer()
            if result.errors > 0 {
                Text("\(result.errors) ✕").foregroundStyle(.red)
            }
            Text(seconds(result.time)).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private func seconds(_ t: TimeInterval) -> String {
        String(format: "%.1f s", t)
    }
}
