import SwiftUI

/// Teclado en pantalla para practicar sin piano conectado.
struct PianoKeyboardView: View {
    let range: ClosedRange<Int>
    let naming: NamingStyle
    let onPress: (Int) -> Void

    private let whiteWidth: CGFloat = 44
    private let height: CGFloat = 170

    private static func isWhite(_ midi: Int) -> Bool {
        [0, 2, 4, 5, 7, 9, 11].contains(((midi % 12) + 12) % 12)
    }

    private var whiteKeys: [Int] { range.filter(Self.isWhite) }
    private var blackKeys: [Int] { range.filter { !Self.isWhite($0) } }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(whiteKeys, id: \.self) { midi in
                            Button { onPress(midi) } label: {
                                VStack {
                                    Spacer()
                                    if midi % 12 == 0 {
                                        Text(Note.pitchName(midi: midi, style: naming, octave: true))
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                            .padding(.bottom, 6)
                                    }
                                }
                            }
                            .buttonStyle(PianoKeyStyle(isWhite: true))
                            .frame(width: whiteWidth, height: height)
                            .id(midi)
                        }
                    }
                    ForEach(blackKeys, id: \.self) { midi in
                        Button { onPress(midi) } label: { Color.clear }
                            .buttonStyle(PianoKeyStyle(isWhite: false))
                            .frame(width: whiteWidth * 0.6, height: height * 0.62)
                            .offset(x: CGFloat(whiteKeys.filter { $0 < midi }.count) * whiteWidth - whiteWidth * 0.3)
                    }
                }
                .frame(height: height)
            }
            .onAppear { proxy.scrollTo(60, anchor: .center) }
        }
        .frame(height: height)
    }
}

private struct PianoKeyStyle: ButtonStyle {
    let isWhite: Bool

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = isWhite
            ? (configuration.isPressed ? Color(white: 0.8) : .white)
            : (configuration.isPressed ? Color(white: 0.35) : .black)
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(UnevenRoundedRectangle(bottomLeadingRadius: 5, bottomTrailingRadius: 5).fill(fill))
            .overlay(UnevenRoundedRectangle(bottomLeadingRadius: 5, bottomTrailingRadius: 5).stroke(Color.gray.opacity(0.6), lineWidth: 1))
            .contentShape(Rectangle())
    }
}
