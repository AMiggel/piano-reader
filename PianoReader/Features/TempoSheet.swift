import SwiftUI

/// Hoja para cambiar el tempo durante la práctica (se abre tocando el tempo).
struct TempoSheet: View {
    let onApply: (Int) -> Void
    @State private var value: Int
    @Environment(\.dismiss) private var dismiss

    init(bpm: Int, onApply: @escaping (Int) -> Void) {
        self.onApply = onApply
        _value = State(initialValue: bpm)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Tempo").font(.headline)
            HStack(spacing: 24) {
                Button { value = max(40, value - 5) } label: {
                    Image(systemName: "minus.circle.fill").font(.largeTitle)
                }
                .disabled(value <= 40)
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("BPM").font(.caption).foregroundStyle(.secondary)
                }
                .frame(minWidth: 120)
                Button { value = min(200, value + 5) } label: {
                    Image(systemName: "plus.circle.fill").font(.largeTitle)
                }
                .disabled(value >= 200)
            }
            Slider(
                value: Binding(get: { Double(value) }, set: { value = Int(($0 / 5).rounded()) * 5 }),
                in: 40...200,
                step: 5
            )
            Button {
                onApply(value)
                dismiss()
            } label: {
                Text("Aplicar").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .presentationDetents([.height(320)])
    }
}
