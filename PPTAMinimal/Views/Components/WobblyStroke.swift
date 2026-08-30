//
//  WobblyStroke.swift
//  PPTAMinimal
//
//  Hand-drawn geometry for onboarding chrome.
//
//  The onboarding illustrations are rough marker line art. Stock SwiftUI geometry — a perfect
//  `Circle()` page dot, a hairline `Divider()` — sits next to that art with a visible seam, and
//  the illustration ends up reading as something pasted in rather than part of the screen. These
//  shapes put a small, deliberate imperfection back into the chrome so the two match.
//
//  Every offset is derived from `seed` plus the point's index — never from a random source and
//  never from time. A `Shape` is re-evaluated on every layout pass, so an unseeded random would
//  re-jitter on each render and the lines would visibly crawl while the user reads the screen.
//

import SwiftUI

// MARK: - Seeded jitter

/// Deterministic pseudo-random offset for one point.
///
/// Amplitude is intentionally tiny (1–2 pt at these sizes). Past roughly 3 pt the result stops
/// reading as "drawn by hand" and starts reading as "rendered incorrectly".
private func wobbleOffset(seed: Int, index: Int, amplitude: CGFloat) -> CGSize {
    var hash = UInt64(bitPattern: Int64(seed &* 73_856_093 ^ (index &+ 1) &* 19_349_663))
    hash ^= hash >> 33
    hash = hash &* 0xff51_afd7_ed55_8ccd
    hash ^= hash >> 33
    let dx = CGFloat(hash % 2_000) / 1_000 - 1          // -1 ... 1
    let dy = CGFloat((hash >> 21) % 2_000) / 1_000 - 1  // -1 ... 1
    return CGSize(width: dx * amplitude, height: dy * amplitude)
}

// MARK: - Shapes

/// A circle drawn as if by hand: slightly out of round, and never quite closing where it started.
struct WobblyCircle: Shape {
    var seed: Int = 0
    var amplitude: CGFloat = 1.4
    /// How far past its own start the stroke carries, as a fraction of the full sweep. Matches the
    /// way a marker overshoots when you loop back to close a circle.
    var overshoot: CGFloat = 0.04

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let segments = 18
        let total = CGFloat(segments) * (1 + overshoot)

        var path = Path()
        for step in 0...Int(total.rounded()) {
            let angle = (CGFloat(step) / CGFloat(segments)) * 2 * .pi - .pi / 2
            let offset = wobbleOffset(seed: seed, index: step % segments, amplitude: amplitude)
            let point = CGPoint(
                x: center.x + cos(angle) * radius + offset.width,
                y: center.y + sin(angle) * radius + offset.height
            )
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// A horizontal rule that wavers gently along its length. Replaces `Divider()`.
struct WobblyLine: Shape {
    var seed: Int = 0
    var amplitude: CGFloat = 1.0

    func path(in rect: CGRect) -> Path {
        let segments = 12
        var path = Path()
        for step in 0...segments {
            let t = CGFloat(step) / CGFloat(segments)
            let offset = wobbleOffset(seed: seed, index: step, amplitude: amplitude)
            let point = CGPoint(
                x: rect.minX + rect.width * t,
                y: rect.midY + offset.height
            )
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// A rounded rectangle with hand-drawn edges, for stroking the outline of a card or button.
///
/// Only ever use this to *stroke*. Filling it exposes the wobble as a ragged silhouette against
/// whatever sits behind, which reads as a rendering fault rather than as a drawing.
struct WobblyRoundedRect: Shape {
    var cornerRadius: CGFloat = 12
    var seed: Int = 0
    var amplitude: CGFloat = 1.2

    func path(in rect: CGRect) -> Path {
        let base = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        let samples = 48
        var path = Path()
        for step in 0...samples {
            let fraction = CGFloat(step) / CGFloat(samples)
            guard let point = base.trimmedPath(from: 0, to: max(fraction, 0.0001)).currentPoint else { continue }
            let offset = wobbleOffset(seed: seed, index: step, amplitude: amplitude)
            let jittered = CGPoint(x: point.x + offset.width, y: point.y + offset.height)
            if path.isEmpty { path.move(to: jittered) } else { path.addLine(to: jittered) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Convenience

extension View {
    /// Replaces `Divider()` with a hand-drawn rule in the app's primary tint.
    func wobblyDivider(seed: Int = 0, opacity: Double = 0.25) -> some View {
        self.overlay(alignment: .bottom) {
            WobblyLine(seed: seed)
                .stroke(
                    Color("primaryColor").opacity(opacity),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
                .frame(height: 3)
        }
    }
}

#Preview {
    VStack(spacing: 28) {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { index in
                WobblyCircle(seed: index)
                    .stroke(Color("primaryColor"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 10, height: 10)
            }
        }
        WobblyLine(seed: 3)
            .stroke(Color("primaryColor").opacity(0.3), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(height: 4)
        WobblyRoundedRect(cornerRadius: 12, seed: 7)
            .stroke(Color("primaryColor"), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(height: 56)
    }
    .padding(40)
}
