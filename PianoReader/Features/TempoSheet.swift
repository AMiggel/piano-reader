import SwiftUI

/// Hoja para cambiar tempo y compás durante la práctica (se abre tocando el tempo).
struct TempoSheet: View {
    let onApply: (Int, Meter) -> Void
    @State private var value: Int
    @State private var meter: Meter
    @Environment(\.dismiss) private var dismiss

    init(bpm: Int, meter: Meter, onApply: @escaping (Int, Meter) -> Void) {
        self.onApply = onApply
        _value = State(initialValue: bpm)
        _meter = State(initialValue: meter)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Tempo, compás y volumen").font(.headline)

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
                    Text(TempoMark.mark(for: value).name)
                        .font(.headline.italic())
                        .foregroundStyle(Color.accentColor)
                }
                .frame(minWidth: 120)
                Button { value = min(220, value + 5) } label: {
                    Image(systemName: "plus.circle.fill").font(.largeTitle)
                }
                .disabled(value >= 220)
            }
            Text(TempoMark.mark(for: value).meaning)
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(get: { Double(value) }, set: { value = Int(($0 / 5).rounded()) * 5 }),
                in: 40...220,
                step: 5
            )
            // Términos italianos: tocar uno pone su tempo típico.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TempoMark.allCases.filter { $0.bpm >= 40 }) { mark in
                        Button(mark.name) { value = mark.bpm }
                            .buttonStyle(.bordered)
                            .tint(TempoMark.mark(for: value) == mark ? Color.accentColor : Color.gray)
                            .font(.caption.italic())
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Volumen del metrónomo").font(.caption).foregroundStyle(.secondary)
                ClickVolumeSlider()
            }
            HStack {
                Text("Compás")
                Spacer()
                Picker("Compás", selection: $meter) {
                    ForEach(Meter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }
            Button {
                onApply(value, meter)
                dismiss()
            } label: {
                Text("Aplicar").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .presentationDetents([.height(540)])
    }
}
