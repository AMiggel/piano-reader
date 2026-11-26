import SwiftUI

/// Pentagrama (o pentagrama doble para las dos manos) con figuras: plicas, corchetes, barras,
/// puntillos, silencios, tresillos, acordes, ligaduras, barras de compás y línea de reproducción.
struct RhythmStaffView: View {
    let exercise: RhythmExercise
    /// Color por voz y evento (nil = negro).
    let colors: [[Color?]]
    let playhead: Double?
    /// Lo que estás tocando: en qué pentagrama (voz) y qué nota.
    var ghosts: [(voice: Int, note: Note)] = []

    private let sp: CGFloat = 13 // espacio entre líneas
    private let ink = Color.black
    private var grand: Bool { exercise.voices.count > 1 }
    private var height: CGFloat { grand ? 360 : 220 }
    private var left: CGFloat { grand ? 20 : 10 }
    /// Clave + armadura + compás.
    private var keyWidth: CGFloat { CGFloat(abs(exercise.key.fifths)) * sp * 0.9 }
    private var header: CGFloat { left + 76 + keyWidth }

    /// Espaciado común a las dos manos: lo que empieza a la vez queda alineado.
    /// Cada momento ocupa √(tiempo hasta el siguiente) unidades.
    private struct Layout {
        var unitAt: [Int: Double] = [:]
        var ticks: [Int] = []
        var bars: [Double] = []
        var total: Double = 0

        init(_ exercise: RhythmExercise) {
            var signed: [Int: Int] = [:]
            var starts: Set<Int> = []
            for voice in exercise.voices {
                let signs = voice.displayedAccidentals(key: exercise.key, measures: exercise.measures)
                for (i, e) in voice.events.enumerated() {
                    starts.insert(e.tick)
                    let count = signs[i]?.compactMap { $0 }.count ?? 0
                    signed[e.tick] = max(signed[e.tick] ?? 0, count)
                }
            }
            let sorted = starts.sorted()
            let measureTicks = exercise.meter.measureTicks
            var u = 0.6
            for (k, t) in sorted.enumerated() {
                if k > 0 && t / measureTicks != sorted[k - 1] / measureTicks {
                    bars.append(u + 0.1)
                    u += 0.9
                }
                let count = signed[t] ?? 0
                if count > 0 { u += count > 1 ? 1.6 : 0.8 } // sitio para ♯ ♭ ♮
                unitAt[t] = u + 0.5
                let next = k + 1 < sorted.count ? sorted[k + 1] : exercise.totalTicks
                u += (Double(max(next - t, 6)) / 12).squareRoot()
            }
            ticks = sorted
            total = u + 0.6
        }
    }

    var body: some View {
        let layout = Layout(exercise)
        GeometryReader { geo in
            let width = max(geo.size.width, header + 20 + CGFloat(layout.total) * 22)
            ScrollView(.horizontal, showsIndicators: false) {
                Canvas { ctx, size in
                    draw(ctx, size: size, layout: layout)
                }
                .frame(width: width, height: height)
                .background(RoundedRectangle(cornerRadius: 16).fill(.white))
            }
        }
        .frame(height: height)
    }

    // MARK: - Dibujo

    private func draw(_ ctx: GraphicsContext, size: CGSize, layout: Layout) {
        let right = size.width - 10
        let startX = header
        let scale = (right - startX) / CGFloat(layout.total)
        func x(_ u: Double) -> CGFloat { startX + CGFloat(u) * scale }
        let centers: [CGFloat] = grand ? [size.height * 0.3, size.height * 0.72] : [size.height / 2]
        let top = centers[0] - 2 * sp
        let bottom = centers[centers.count - 1] + 2 * sp

        for (v, voice) in exercise.voices.enumerated() {
            let bottomY = centers[v] + 2 * sp
            let y: (Double) -> CGFloat = { step in bottomY - CGFloat(step) * sp / 2 }

            for l in stride(from: 0, through: 8, by: 2) {
                line(ctx, left, y(Double(l)), right, y(Double(l)), 1.1, ink)
            }
            let clefText = voice.clef == .treble
                ? Text("𝄞").font(.system(size: sp * 6.2))
                : Text("𝄢").font(.system(size: sp * 3.6))
            ctx.draw(clefText.foregroundColor(ink),
                     at: CGPoint(x: left + 22, y: y(voice.clef == .treble ? 3 : 5)), anchor: .center)
            StaffGlyphs.keySignature(ctx, exercise.key, clef: voice.clef, startX: left + 46, sp: sp, y: y)
            let tsFont = Font.system(size: sp * 2.1, weight: .heavy, design: .serif)
            ctx.draw(Text(exercise.meter.numerator).font(tsFont).foregroundColor(ink),
                     at: CGPoint(x: left + 56 + keyWidth, y: y(6)), anchor: .center)
            ctx.draw(Text(exercise.meter.denominator).font(tsFont).foregroundColor(ink),
                     at: CGPoint(x: left + 56 + keyWidth, y: y(2)), anchor: .center)

            let xs = voice.events.map { x(layout.unitAt[$0.tick] ?? 0) }
            drawVoice(ctx, voice: voice, colors: v < colors.count ? colors[v] : [], xs: xs, y: y)
        }

        // Barras de compás (cruzan los dos pentagramas) y doble barra final
        for bar in layout.bars {
            line(ctx, x(bar), top, x(bar), bottom, 1.2, ink)
        }
        line(ctx, right - 6, top, right - 6, bottom, 1.2, ink)
        line(ctx, right - 1.5, top, right - 1.5, bottom, 3, ink)
        if grand {
            line(ctx, left, top, left, bottom, 1.2, ink)
            let mid = (top + bottom) / 2
            var brace = Path()
            brace.move(to: CGPoint(x: left - 4, y: top))
            brace.addQuadCurve(to: CGPoint(x: left - 12, y: mid), control: CGPoint(x: left - 16, y: top + (mid - top) * 0.7))
            brace.addQuadCurve(to: CGPoint(x: left - 4, y: bottom), control: CGPoint(x: left - 16, y: bottom - (bottom - mid) * 0.7))
            ctx.stroke(brace, with: .color(ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }

        // Línea de reproducción
        var px = x(layout.unitAt[layout.ticks.first ?? 0] ?? 0)
        if let playhead {
            var points: [(tick: Double, x: CGFloat)] = layout.ticks.map { (tick: Double($0), x: x(layout.unitAt[$0] ?? 0)) }
            points.append((tick: Double(exercise.totalTicks), x: right - 8))
            for k in 0..<(points.count - 1) where playhead >= points[k].tick {
                let a = points[k], b = points[k + 1]
                let span = max(b.tick - a.tick, 0.001)
                px = a.x + (b.x - a.x) * CGFloat(min((playhead - a.tick) / span, 1))
            }
            line(ctx, px, top - sp * 1.5, px, bottom + sp * 1.5, 2, Color.blue.opacity(0.45))
        }

        // Lo que estás tocando, en azul, justo a la derecha de la línea.
        let ghostColor = Color.blue.opacity(0.65)
        let gx = px + sp * 1.8
        for ghost in ghosts where ghost.voice < exercise.voices.count {
            let clef = exercise.voices[ghost.voice].clef
            let bottomY = centers[ghost.voice] + 2 * sp
            let y: (Double) -> CGFloat = { step in bottomY - CGFloat(step) * sp / 2 }
            let st = ghost.note.diatonic - clef.bottomLine
            ledgers(ctx, x: gx, step: st, y: y)
            head(ctx, at: CGPoint(x: gx, y: y(Double(st))), value: .quarter, color: ghostColor)
            if ghost.note.accidental != exercise.key.accidental(for: ghost.note.letter) {
                StaffGlyphs.accidental(ctx, ghost.note.accidental, at: CGPoint(x: gx - sp * 1.6, y: y(Double(st))),
                                       sp: sp, color: ghostColor)
            }
        }
    }

    private func drawVoice(_ ctx: GraphicsContext, voice: Voice, colors: [Color?], xs: [CGFloat], y: (Double) -> CGFloat) {
        let clef = voice.clef
        let events = voice.events
        let signs = voice.displayedAccidentals(key: exercise.key, measures: exercise.measures)

        // Cada evento puede ser acorde: pasos de grave a agudo.
        let chords: [[Int]] = events.map { e in e.notes.map { $0.diatonic - clef.bottomLine }.sorted() }
        let steps: [Int?] = chords.map { $0.first }
        let low: [Int] = chords.map { $0.first ?? 4 }
        let high: [Int] = chords.map { $0.last ?? 4 }
        func color(_ i: Int) -> Color { (colors.indices.contains(i) ? colors[i] : nil) ?? ink }

        var beams: [Int: [Int]] = [:]
        var tuplets: [Int: [Int]] = [:]
        for (i, e) in events.enumerated() {
            if let g = e.beamGroup { beams[g, default: []].append(i) }
            if let t = e.tupletGroup { tuplets[t, default: []].append(i) }
        }
        var stemUp = events.indices.map { Double(low[$0] + high[$0]) / 2 < 4 }
        for members in beams.values {
            let sum = members.reduce(0.0) { $0 + Double(low[$1] + high[$1]) / 2 }
            for i in members { stemUp[i] = sum / Double(members.count) < 4 }
        }

        // Notas (o acordes) y silencios
        for i in events.indices {
            let e = events[i]
            guard !chords[i].isEmpty else {
                rest(ctx, value: e.item.value, x: xs[i], y: y)
                continue
            }
            let order = e.notes.indices.sorted { e.notes[$0].diatonic < e.notes[$1].diatonic }
            var previous: Int?
            var previousShifted = false
            var signCount = 0
            for j in order {
                let st = e.notes[j].diatonic - clef.bottomLine
                // Segunda en acorde: una de las dos cabezas va al otro lado de la plica.
                let shifted = previous.map { st - $0 == 1 } == true && !previousShifted
                previous = st
                previousShifted = shifted
                let hx = xs[i] + (shifted ? (stemUp[i] ? sp * 1.24 : -sp * 1.24) : 0)
                let cy = y(Double(st))
                ledgers(ctx, x: hx, step: st, y: y)
                head(ctx, at: CGPoint(x: hx, y: cy), value: e.item.value, color: color(i))
                if let list = signs[i], list.indices.contains(j), let sign = list[j] {
                    let sx = xs[i] - sp * 1.6 - CGFloat(signCount % 2) * sp * 1.0
                    StaffGlyphs.accidental(ctx, sign, at: CGPoint(x: sx, y: cy), sp: sp, color: color(i))
                    signCount += 1
                }
                if e.item.dotted {
                    let dy = st % 2 == 0 ? y(Double(st + 1)) : cy
                    let r = sp * 0.16
                    ctx.fill(Path(ellipseIn: CGRect(x: xs[i] + sp * 1.0 - r, y: dy - r, width: r * 2, height: r * 2)),
                             with: .color(color(i)))
                }
            }
            if e.item.value.hasStem && e.beamGroup == nil {
                let up = stemUp[i]
                let sx = xs[i] + (up ? sp * 0.62 : -sp * 0.62)
                let start = up ? y(Double(low[i])) : y(Double(high[i]))
                let tip = up ? y(Double(high[i])) - sp * 3.3 : y(Double(low[i])) + sp * 3.3
                line(ctx, sx, start, sx, tip, 1.3, color(i))
                flags(ctx, stemX: sx, tipY: tip, count: e.item.value.beams, up: up, color: color(i))
            }
        }

        // Barras de corcheas/semicorcheas
        for members in beams.values {
            let up = stemUp[members[0]]
            let ys = members.map { up ? y(Double(low[$0])) : y(Double(high[$0])) }
            let tips = members.map { up ? y(Double(high[$0])) : y(Double(low[$0])) }
            let beamY = up ? (tips.min() ?? 0) - sp * 3.3 : (tips.max() ?? 0) + sp * 3.3
            let sxs = members.map { xs[$0] + (up ? sp * 0.62 : -sp * 0.62) }
            for k in members.indices {
                line(ctx, sxs[k], ys[k], sxs[k], beamY, 1.3, color(members[k]))
            }
            let toHead: CGFloat = up ? 1 : -1
            beam(ctx, from: sxs[0], to: sxs[sxs.count - 1], y: beamY, toHead: toHead)
            let second = beamY + toHead * sp * 0.75
            for k in members.indices where events[members[k]].item.value.beams >= 2 {
                let next16 = k + 1 < members.count && events[members[k + 1]].item.value.beams >= 2
                let prev16 = k > 0 && events[members[k - 1]].item.value.beams >= 2
                if next16 {
                    beam(ctx, from: sxs[k], to: sxs[k + 1], y: second, toHead: toHead)
                } else if !prev16 {
                    // Semicorchea suelta en el grupo (p. ej. saltillo): barrita corta.
                    if k == members.count - 1 {
                        beam(ctx, from: sxs[k] - sp, to: sxs[k], y: second, toHead: toHead)
                    } else {
                        beam(ctx, from: sxs[k], to: sxs[k] + sp, y: second, toHead: toHead)
                    }
                }
            }
        }

        // Tresillos
        for members in tuplets.values {
            guard let first = members.first, let last = members.last else { continue }
            let up = stemUp[first]
            let tips = members.map { up ? y(Double(high[$0])) : y(Double(low[$0])) }
            let ty = up ? (tips.min() ?? 0) - sp * 4.4 : (tips.max() ?? 0) + sp * 4.4
            let cx = (xs[first] + xs[last]) / 2 + (up ? sp * 0.62 : -sp * 0.62)
            ctx.draw(Text("3").font(.system(size: sp * 1.2, weight: .semibold).italic()).foregroundColor(ink),
                     at: CGPoint(x: cx, y: ty), anchor: .center)
        }

        // Ligaduras de prolongación
        for i in events.indices.dropLast() where events[i].tiedToNext {
            guard let st = steps[i] else { continue }
            let below = stemUp[i] || !events[i].item.value.hasStem
            let yb = y(Double(st)) + (below ? sp * 0.65 : -sp * 0.65)
            curve(ctx, from: CGPoint(x: xs[i] + sp * 0.5, y: yb), to: CGPoint(x: xs[i + 1] - sp * 0.5, y: yb),
                  controlY: yb + (below ? sp * 0.9 : -sp * 0.9), color: color(i))
        }

        // Ligaduras de expresión
        for slur in voice.slurs {
            let a = slur.lowerBound, b = slur.upperBound
            let ys = slur.map { y(Double(steps[$0] ?? 4)) }
            let below = stemUp[a]
            let offset = below ? sp * 0.9 : -sp * 0.9
            let extreme = below ? (ys.max() ?? 0) + sp * 2.2 : (ys.min() ?? 0) - sp * 2.2
            curve(ctx, from: CGPoint(x: xs[a], y: y(Double(steps[a] ?? 4)) + offset),
                  to: CGPoint(x: xs[b], y: y(Double(steps[b] ?? 4)) + offset),
                  controlY: extreme, color: ink)
        }
    }

    // MARK: - Piezas

    private func line(_ ctx: GraphicsContext, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat,
                      _ width: CGFloat, _ color: Color) {
        var p = Path()
        p.move(to: CGPoint(x: x1, y: y1))
        p.addLine(to: CGPoint(x: x2, y: y2))
        ctx.stroke(p, with: .color(color), lineWidth: width)
    }

    private func ledgers(_ ctx: GraphicsContext, x: CGFloat, step: Int, y: (Double) -> CGFloat) {
        var list: [Int] = []
        if step <= -2 { list = Array(stride(from: -2, through: step, by: -2)) }
        if step >= 10 { list = Array(stride(from: 10, through: step, by: 2)) }
        for l in list {
            line(ctx, x - sp * 1.05, y(Double(l)), x + sp * 1.05, y(Double(l)), 1.1, ink)
        }
    }

    private func head(_ ctx: GraphicsContext, at c: CGPoint, value: NoteValue, color: Color) {
        let move = CGAffineTransform(translationX: c.x, y: c.y)
        var path: Path
        if value == .whole {
            path = Path(ellipseIn: CGRect(x: c.x - sp * 0.8, y: c.y - sp * 0.53, width: sp * 1.6, height: sp * 1.06))
            path.addPath(Path(ellipseIn: CGRect(x: -sp * 0.42, y: -sp * 0.28, width: sp * 0.84, height: sp * 0.56))
                .applying(CGAffineTransform(rotationAngle: -.pi / 3))
                .applying(move))
        } else {
            path = Path(ellipseIn: CGRect(x: -sp * 0.68, y: -sp * 0.46, width: sp * 1.36, height: sp * 0.92))
                .applying(CGAffineTransform(rotationAngle: -0.35))
                .applying(move)
            if value == .half {
                path.addPath(Path(ellipseIn: CGRect(x: -sp * 0.55, y: -sp * 0.2, width: sp * 1.1, height: sp * 0.4))
                    .applying(CGAffineTransform(rotationAngle: -0.5))
                    .applying(move))
            }
        }
        ctx.fill(path, with: .color(color), style: FillStyle(eoFill: true))
    }

    private func flags(_ ctx: GraphicsContext, stemX sx: CGFloat, tipY: CGFloat, count: Int, up: Bool, color: Color) {
        let d: CGFloat = up ? 1 : -1
        for k in 0..<count {
            let y0 = tipY + d * CGFloat(k) * sp * 0.75
            var p = Path()
            p.move(to: CGPoint(x: sx, y: y0))
            p.addCurve(to: CGPoint(x: sx + sp * 0.8, y: y0 + d * sp * 2.0),
                       control1: CGPoint(x: sx + sp * 0.1, y: y0 + d * sp * 0.9),
                       control2: CGPoint(x: sx + sp * 1.1, y: y0 + d * sp * 1.1))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    /// `toHead`: +1 si la barra crece hacia abajo (plicas arriba), −1 al revés.
    private func beam(_ ctx: GraphicsContext, from x1: CGFloat, to x2: CGFloat, y: CGFloat, toHead: CGFloat) {
        let thick = sp * 0.45
        let top = toHead > 0 ? y : y - thick
        ctx.fill(Path(CGRect(x: min(x1, x2) - 0.6, y: top, width: abs(x2 - x1) + 1.2, height: thick)), with: .color(ink))
    }

    private func curve(_ ctx: GraphicsContext, from a: CGPoint, to b: CGPoint, controlY: CGFloat, color: Color) {
        var p = Path()
        p.move(to: a)
        p.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: controlY))
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    private func rest(_ ctx: GraphicsContext, value: NoteValue, x: CGFloat, y: (Double) -> CGFloat) {
        switch value {
        case .whole:
            ctx.fill(Path(CGRect(x: x - sp * 0.6, y: y(6), width: sp * 1.2, height: sp * 0.5)), with: .color(ink))
        case .half:
            ctx.fill(Path(CGRect(x: x - sp * 0.6, y: y(4) - sp * 0.5, width: sp * 1.2, height: sp * 0.5)), with: .color(ink))
        case .quarter:
            var p = Path()
            p.move(to: CGPoint(x: x - sp * 0.15, y: y(7)))
            p.addLine(to: CGPoint(x: x + sp * 0.35, y: y(5.6)))
            p.addLine(to: CGPoint(x: x - sp * 0.25, y: y(4.2)))
            p.addLine(to: CGPoint(x: x + sp * 0.3, y: y(3)))
            p.addQuadCurve(to: CGPoint(x: x, y: y(1.6)), control: CGPoint(x: x - sp * 0.6, y: y(2.6)))
            ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: sp * 0.28, lineCap: .round, lineJoin: .round))
        case .eighth, .sixteenth:
            let count = value.beams
            let top = y(6)
            line(ctx, x + sp * 0.45, top, x - sp * 0.1, count == 1 ? y(2.5) : y(1), 1.4, ink)
            for k in 0..<count {
                let ky = top + CGFloat(k) * sp * 0.9
                let kx = x + sp * 0.45 - CGFloat(k) * sp * 0.15
                ctx.fill(Path(ellipseIn: CGRect(x: kx - sp * 0.95, y: ky - sp * 0.05, width: sp * 0.45, height: sp * 0.45)),
                         with: .color(ink))
                var arm = Path()
                arm.move(to: CGPoint(x: kx - sp * 0.75, y: ky + sp * 0.2))
                arm.addQuadCurve(to: CGPoint(x: kx, y: ky), control: CGPoint(x: kx - sp * 0.3, y: ky + sp * 0.35))
                ctx.stroke(arm, with: .color(ink), lineWidth: 1.4)
            }
        }
    }
}
