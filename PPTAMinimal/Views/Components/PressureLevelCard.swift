//
//  PressureLevelCard.swift
//  PPTAMinimal
//
//  Extracted from `PressureLevelView` so onboarding and Settings offer the same control.
//
//  Kept visually identical to the original private `pressureCard(...)`: a trainee who picks
//  "Hardcore" during onboarding and later opens Settings should be looking at the same card, not
//  at a second design that happens to mean the same thing.
//

import SwiftUI

struct PressureLevelCard: View {
    let level: PressureLevel
    let title: String
    let description: String
    let backgroundColor: Color
    let textColor: Color
    var showStar: Bool = false
    @Binding var selection: PressureLevel

    var body: some View {
        Button {
            selection = level
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .stroke(Color.primary.opacity(textColor == .white ? 0.5 : 0.3), lineWidth: 2)
                    .background(
                        Circle()
                            .fill(selection == level ? (textColor == .white ? Color.white : Color.primary) : Color.clear)
                            .scaleEffect(selection == level ? 0.5 : 0)
                    )
                    .frame(width: 24, height: 24)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(textColor.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showStar {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct Harness: View {
        @State private var selection: PressureLevel = .standard
        var body: some View {
            VStack(spacing: 12) {
                PressureLevelCard(
                    level: .standard,
                    title: "Standard",
                    description: "Coaches can lock you out when you go over.",
                    backgroundColor: Color("primaryButtonColor"),
                    textColor: .white,
                    showStar: true,
                    selection: $selection
                )
                PressureLevelCard(
                    level: .hardcore,
                    title: "Hardcore",
                    description: "Your apps lock the moment you hit the limit.",
                    backgroundColor: Color("primaryColor"),
                    textColor: .white,
                    selection: $selection
                )
            }
            .padding()
        }
    }
    return Harness()
}
