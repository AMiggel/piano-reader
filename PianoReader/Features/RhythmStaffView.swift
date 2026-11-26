import SwiftUI

/// Pentagrama con figuras: plicas, corchetes, barras, puntillos, silencios,
/// tresillos, ligaduras de prolongación y de expresión, barras de compás y línea de reproducción.
struct RhythmStaffView: View {
    let exercise: RhythmExercise
    let colors: [Color?]
    let playhead: Double?

    private let sp: CGFloat = 13 // espacio entre líneas
    private let ink = Color.black
    private let height: CGFloat = 220
    private let header: CGFloat = 76 // clave + compás

    /// Espaciado: cada figura ocupa √(duración) unidades, así se ve el ritmo sin amontonar.
    private struct Layout {
        var units: [Double] = []
        var bars: [Double] = []
        var total: Double = 0

        init(_ exercise: RhythmExercise) {
            var u = 0.6
            for (i, e) in exercise.events.enumerated() {
                if i > 0 && e.measure != exercise.events[i - 1].measure {
                    bars.append(u + 0.1)
                    u += 0.9
                }
                units.append(u + 0.5)
                u += (Double(e.item.ticks) / 12).squareRoot()
            }
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
        let bottomY = size.height / 2 + 2 * sp
        func y(_ step: Double) -> CGFloat { bottomY - CGFloat(step) * sp / 2 }
        let left: CGFloat = 10
        let right = size.width - 10
        let startX = left + header
        let scale = (right - startX) / CGFloat(layout.total)
        func x(_ u: Double) -> CGFloat { startX + CGFloat(u) * scale }

        for l in stride(from: 0, through: 8, by: 2) {
            line(ctx, left, y(Double(l)), right, y(Double(l)), 1.1, ink)
        }

        // Clave y compás
        let clef = exercise.clef
        let clefText = clef == .treble
            ? Text("𝄞").font(.system(size: sp * 6.2))
            : Text("𝄢").font(.system(size: sp * 3.6))
        ctx.draw(clefText.foregroundColor(ink), at: CGPoint(x: left + 22, y: y(clef == .treble ? 3 : 5)), anchor: .center)
        let tsFont = Font.system(size: sp * 2.1, weight: .heavy, design: .serif)
        ctx.draw(Text(exercise.meter.numerator).font(tsFont).foregroundColor(ink), at: CGPoint(x: left + 56, y: y(6)), anchor: .center)
        ctx.draw(Text(exercise.meter.denominator).font(tsFont).foregroundColor(ink), at: CGPoint(x: left + 56, y: y(2)), anchor: .center)

        let events = exercise.events
        let xs = layout.units.map { x($0) }
        let steps: [Int?] = events.map { e in e.note.map { $0.diatonic - clef.bottomLine } }
        func color(_ i: Int) -> Color { (colors.indices.contains(i) ? colors[i] : nil) ?? ink }

        var beams: [Int: [Int]] = [:]
        var tuplets: [Int: [Int]] = [:]
        for (i, e) in events.enumerated() {
            if let g = e.beamGroup { beams[g, default: []].append(i) }
            if let t = e.tupletGroup { tuplets[t, default: []].append(i) }
        }
        var stemUp = steps.map { ($0 ?? 0) < 4 }
        for members in beams.values {
            let sum = members.compactMap { steps[$0] }.reduce(0, +)
            for i in members { stemUp[i] = Double(sum) / Double(members.count) < 4 }
        }

        // Notas y silencios
        for i in events.indices {
            let e = events[i]
            guard let st = steps[i] else {
                rest(ctx, value: e.item.value, x: xs[i], y: y)
                continue
            }
            let cy = y(Double(st))
            ledgers(ctx, x: xs[i], step: st, y: y)
            head(ctx, at: CGPoint(x: xs[i], y: cy), value: e.item.value, color: color(i))
            if e.item.dotted {
                let dy = st % 2 == 0 ? y(Double(st + 1)) : cy
                let r = sp * 0.16
                ctx.fill(Path(ellipseIn: CGRect(x: xs[i] + sp * 1.0 - r, y: dy - r, width: r * 2, height: r * 2)),
                         with: .color(color(i)))
            }
            if e.item.value.hasStem && e.beamGroup == nil {
                let up = stemUp[i]
                let sx = xs[i] + (up ? sp * 0.62 : -sp * 0.62)
                let tip = cy + (up ? -sp * 3.3 : sp * 3.3)
                line(ctx, sx, cy, sx, tip, 1.3, color(i))
                flags(ctx, stemX: sx, tipY: tip, count: e.item.value.beams, up: up, color: color(i))
            }
        }

        // Barras de corcheas/semicorcheas
        for members in beams.values {
            let up = stemUp[members[0]]
            let ys = members.map { y(Double(steps[$0] ?? 4)) }
            let beamY = up ? (ys.min() ?? 0) - sp * 3.3 : (ys.max() ?? 0) + sp * 3.3
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
            let ys = members.map { y(Double(steps[$0] ?? 4)) }
            let ty = up ? (ys.min() ?? 0) - sp * 4.4 : (ys.max() ?? 0) + sp * 4.4
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
        for slur in exercise.slurs {
            let a = slur.lowerBound, b = slur.upperBound
            let ys = slur.map { y(Double(steps[$0] ?? 4)) }
            let below = stemUp[a]
            let offset = below ? sp * 0.9 : -sp * 0.9
            let extreme = below ? (ys.max() ?? 0) + sp * 2.2 : (ys.min() ?? 0) - sp * 2.2
            curve(ctx, from: CGPoint(x: xs[a], y: y(Double(steps[a] ?? 4)) + offset),
                  to: CGPoint(x: xs[b], y: y(Double(steps[b] ?? 4)) + offset),
                  controlY: extreme, color: ink)
        }

        // Barras de compás y doble barra final
        for bar in layout.bars {
            line(ctx, x(bar), y(0), x(bar), y(8), 1.2, ink)
        }
        line(ctx, right - 6, y(0), right - 6, y(8), 1.2, ink)
        line(ctx, right - 1.5, y(0), right - 1.5, y(8), 3, ink)

        // Línea de reproducción
        if let playhead {
            var points: [(tick: Double, x: CGFloat)] = events.indices.map { (tick: Double(events[$0].tick), x: xs[$0]) }
            points.append((tick: Double(exercise.totalTicks), x: right - 8))
            var px = points[0].x
            for k in 0..<(points.count - 1) where playhead >= points[k].tick {
                let a = points[k], b = points[k + 1]
                let span = max(b.tick - a.tick, 0.001)
                px = a.x + (b.x - a.x) * CGFloat(min((playhead - a.tick) / span, 1))
            }
            line(ctx, px, y(-3), px, y(11), 2, Color.blue.opacity(0.45))
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
