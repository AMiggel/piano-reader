import SwiftUI

/// Teclado en pantalla: una octava y media visible con flechas para subir o bajar de octava.
/// Sin ScrollView, así las teclas responden al instante.
struct PianoKeyboardView: View {
    let naming: NamingStyle
    /// Nota a mostrar (p. ej. la del ejercicio): si queda fuera, el teclado se mueve a su octava.
    var follow: Int? = nil
    let onPress: (Int) -> Void

    @State private var octave = 4 // la primera tecla es C de esta octava
    private let whiteCount = 10   // C a E de la octava siguiente
    private let height: CGFloat = 170
    private let minOctave = 1, maxOctave = 6

    private static func isWhite(_ midi: Int) -> Bool {
        [0, 2, 4, 5, 7, 9, 11].contains(((midi % 12) + 12) % 12)
    }

    private var lowest: Int { (octave + 1) * 12 }
    private var keys: [Int] {
        var result: [Int] = []
        var midi = lowest
        while result.filter(Self.isWhite).count < whiteCount {
            result.append(midi)
            midi += 1
        }
        return result
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button { octave = max(minOctave, octave - 1) } label: {
                    Image(systemName: "chevron.left.circle.fill").font(.title2)
                }
                .disabled(octave <= minOctave)
                Spacer()
                Text("Octava \(octave)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { octave = min(maxOctave, octave + 1) } label: {
                    Image(systemName: "chevron.right.circle.fill").font(.title2)
                }
                .disabled(octave >= maxOctave)
            }

            GeometryReader { geo in
                let whites = keys.filter(Self.isWhite)
                let blacks = keys.filter { !Self.isWhite($0) }
                let whiteWidth = geo.size.width / CGFloat(whites.count)
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(whites, id: \.self) { midi in
                            PianoKey(isWhite: true, label: midi % 12 == 0
                                     ? Note.pitchName(midi: midi, style: naming, octave: true) : nil) {
                                onPress(midi)
                            }
                            .frame(width: whiteWidth, height: height)
                        }
                    }
                    ForEach(blacks, id: \.self) { midi in
                        PianoKey(isWhite: false, label: nil) { onPress(midi) }
                            .frame(width: whiteWidth * 0.6, height: height * 0.62)
                            .offset(x: CGFloat(whites.filter { $0 < midi }.count) * whiteWidth - whiteWidth * 0.3)
                    }
                }
            }
            .frame(height: height)
        }
        .onAppear { center(on: follow) }
        .onChange(of: follow) { _, note in center(on: note) }
    }

    private func center(on midi: Int?) {
        guard let midi, let last = keys.last, midi < lowest || midi > last else { return }
        octave = min(max(midi / 12 - 1, minOctave), maxOctave)
    }
}

/// Suena al tocar (no al soltar) y se ve presionada mientras el dedo está encima.
private struct PianoKey: View {
    let isWhite: Bool
    let label: String?
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        let fill: Color = isWhite
            ? (pressed ? Color(white: 0.8) : .white)
            : (pressed ? Color(white: 0.35) : .black)
        UnevenRoundedRectangle(bottomLeadingRadius: 5, bottomTrailingRadius: 5)
            .fill(fill)
            .overlay(UnevenRoundedRectangle(bottomLeadingRadius: 5, bottomTrailingRadius: 5)
                .stroke(Color.gray.opacity(0.6), lineWidth: 1))
            .overlay(alignment: .bottom) {
                if let label {
                    Text(label).font(.caption2).foregroundStyle(.gray).padding(.bottom, 6)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed {
                            pressed = true
                            action()
                        }
                    }
                    .onEnded { _ in pressed = false }
            )
    }
}
