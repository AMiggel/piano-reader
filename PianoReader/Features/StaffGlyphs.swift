import SwiftUI

/// Signos compartidos por los dos pentagramas.
enum StaffGlyphs {
    /// ♯ ♭ ♮ centrado en la línea o espacio de la nota (el ♭ se sube porque su panza va abajo).
    static func accidental(_ ctx: GraphicsContext, _ accidental: Accidental, at point: CGPoint, sp: CGFloat, color: Color) {
        let dy: CGFloat = accidental == .flat ? -sp * 0.35 : 0
        ctx.draw(
            Text(accidental.mark).font(.system(size: sp * 2.2)).foregroundColor(color),
            at: CGPoint(x: point.x, y: point.y + dy),
            anchor: .center
        )
    }

    static func keySignature(_ ctx: GraphicsContext, _ key: KeySignature, clef: Clef, startX: CGFloat,
                             sp: CGFloat, y: (Double) -> CGFloat) {
        let sign: Accidental = key.fifths > 0 ? .sharp : .flat
        for (i, step) in key.staffSteps(clef).enumerated() {
            accidental(ctx, sign, at: CGPoint(x: startX + CGFloat(i) * sp * 0.9, y: y(Double(step))), sp: sp, color: .black)
        }
    }
}
