//
//  PressureOffHomeCardView.swift
//  PPTAMinimal
//
//  Olive callout when App Limits are off (`pressureLevel == PressureLevel.off`) — nudges Settings to
//  turn them on. Matches `NoAppLimitsHomeCardView` styling.
//

import SwiftUI

struct PressureOffHomeCardView: View {
    private static let oliveFill = Color(red: 0.42, green: 0.50, blue: 0.41)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 48, height: 48)
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.title2)
                    .foregroundStyle(Color.green)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("App Limits Off")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                (
                    Text("Go to ") +
                        Text("Settings").bold() +
                        Text(" and turn ") +
                        Text("App Limits").bold() +
                        Text(" on so your coaches can hold you to your limit.")
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Self.oliveFill)
        )
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }
}

#Preview("App Limits Off card") {
    NavigationStack {
        PressureOffHomeCardView()
    }
    .environmentObject(AuthViewModel())
}
