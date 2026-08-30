//
//  PageIndicator.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/3/25.
//

import SwiftUI

/// Progress dots for the onboarding flow.
///
/// Previously drawn as two `ForEach(0..<page)` / `ForEach(page+1..<length)` loops over
/// *non-constant* ranges without an `id:`. SwiftUI treats a range literal like that as a constant
/// and does not reliably rebuild when it changes, so the dots could stop tracking the flow. One
/// loop over a stable range with an explicit `id:` fixes it.
///
/// Callers should pass `coordinator.progressIndex` / `coordinator.progressTotal` rather than
/// hardcoding a position — that was the other half of the old bug, where adding a step meant
/// editing every screen.
struct PageIndicator: View {
    var page: Int = 0
    var length: Int = 6

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<max(length, 1), id: \.self) { index in
                dot(isActive: index == page, seed: index)
            }
        }
    }

    @ViewBuilder
    private func dot(isActive: Bool, seed: Int) -> some View {
        if isActive {
            WobblyCircle(seed: seed, amplitude: 0.7)
                .fill(Color("primaryColor"))
                .frame(width: 9, height: 9)
        } else {
            WobblyCircle(seed: seed, amplitude: 0.7)
                .stroke(
                    Color("primaryColor").opacity(0.3),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 9, height: 9)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PageIndicator(page: 0, length: 5)
        PageIndicator(page: 2, length: 5)
        PageIndicator(page: 4, length: 5)
    }
}
