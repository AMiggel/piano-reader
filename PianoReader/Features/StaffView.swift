import SwiftUI

/// Pentagrama con redondas. Las notas de cada paso vienen ordenadas de grave a agudo.
struct StaffView: View {
    let session: PracticeSession

    private let sp: CGFloat = 16 // espacio entre líneas
    private let ink = Color.black

    // Ajuste fino de las claves (dependen de la fuente del sistema).
    private let trebleSize: CGFloat = 6.2, trebleStep = 3.0
    private let bassSize: CGFloat = 3.6, bassStep = 5.0

    var body: some View {
        // Leer aquí para que Observation redibuje el Canvas.
        let exercise = session.exercise
        let colors: [[Color?]] = exercise.steps.indices.map { i in
            exercise.steps[i].map { session.color(step: i, note: $0) }
        }

        Canvas { ctx, size in
            let bottomY = size.height / 2 + 2 * sp
            func y(_ step: Double) -> CGFloat { bottomY - CGFloat(step) * sp / 2 }
            let left: CGFloat = 12, right = size.width - 12

            for line in stride(from: 0, through: 8, by: 2) {
                hLine(ctx, from: left, to: right, y: y(Double(line)), width: 1.2)
            }

            let clefPoint = CGPoint(x: left + 26, y: y(exercise.clef == .treble ? trebleStep : bassStep))
            let clefText = exercise.clef == .treble
                ? Text("𝄞").font(.system(size: sp * trebleSize))
                : Text("𝄢").font(.system(size: sp * bassSize))
            ctx.draw(clefText.foregroundColor(ink), at: clefPoint, anchor: .center)

            let startX = left + 70
            let slot = (right - startX) / CGFloat(exercise.steps.count)

            for (i, chord) in exercise.steps.enumerated() {
                let cx = startX + slot * (CGFloat(i) + 0.5)
                var previous: Int?
                var previousShifted = false

                for (j, note) in chord.enumerated() {
                    let step = note.diatonic - exercise.clef.bottomLine
                    // Segundas en acorde: la nota de arriba va a la derecha.
                    let shifted = previous.map { step - $0 == 1 } == true && !previousShifted
                    previous = step
                    previousShifted = shifted
                    let x = cx + (shifted ? sp * 1.4 : 0)
                    let color = colors[i][j] ?? ink

                    var ledgers: [Int] = []
                    if step <= -2 { ledgers = Array(stride(from: -2, through: step, by: -2)) }
                    if step >= 10 { ledgers = Array(stride(from: 10, through: step, by: 2)) }
                    for l in ledgers {
                        hLine(ctx, from: x - sp * 1.15, to: x + sp * 1.15, y: y(Double(l)), width: 1.2)
                    }

                    wholeNote(ctx, at: CGPoint(x: x, y: y(Double(step))), color: color)

                    if note.accidental != .natural {
                        ctx.draw(
                            Text(note.accidental.symbol).font(.system(size: sp * 1.9)).foregroundColor(color),
                            at: CGPoint(x: x - sp * 1.8, y: y(Double(step))),
                            anchor: .center
                        )
                    }
                }
            }
        }
        .frame(height: 210)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.25)))
    }

    private func hLine(_ ctx: GraphicsContext, from x1: CGFloat, to x2: CGFloat, y: CGFloat, width: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: x1, y: y))
        path.addLine(to: CGPoint(x: x2, y: y))
        ctx.stroke(path, with: .color(ink), lineWidth: width)
    }

    private func wholeNote(_ ctx: GraphicsContext, at c: CGPoint, color: Color) {
        var path = Path(ellipseIn: CGRect(x: c.x - sp * 0.8, y: c.y - sp * 0.53, width: sp * 1.6, height: sp * 1.06))
        let hole = Path(ellipseIn: CGRect(x: -sp * 0.42, y: -sp * 0.28, width: sp * 0.84, height: sp * 0.56))
            .applying(CGAffineTransform(rotationAngle: -.pi / 3))
            .applying(CGAffineTransform(translationX: c.x, y: c.y))
        path.addPath(hole)
        ctx.fill(path, with: .color(color), style: FillStyle(eoFill: true))
    }
}

/// Modo "Nombre": muestra G, C-E-G o G → D → E.
struct NoteNameView: View {
    let session: PracticeSession

    var body: some View {
        let exercise = session.exercise
        let s = session.settings
        HStack(spacing: 10) {
            ForEach(Array(exercise.steps.enumerated()), id: \.offset) { i, chord in
                if i > 0 {
                    Image(systemName: "arrow.right").font(.title3).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    ForEach(Array(chord.enumerated()), id: \.offset) { _, note in
                        Text(note.name(s.naming, octave: s.exactOctave))
                            .foregroundStyle(session.color(step: i, note: note) ?? .primary)
                    }
                }
            }
        }
        .font(.system(size: exercise.steps.count > 3 ? 30 : 48, weight: .bold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.4)
    }
}
