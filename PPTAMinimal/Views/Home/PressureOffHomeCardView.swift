//
//  PressureOffHomeCardView.swift
//  PPTAMinimal
//
//  Olive callout when `pressureLevel == "Off"` — nudges Settings and choosing how serious
//  accountability is (Standard vs Hardcore). Matches `NoAppLimitsHomeCardView` styling.
//

import SwiftUI

struct PressureOffHomeCardView: View {
    private static let oliveFill = Color(red: 0.42, green: 0.50, blue: 0.41)

    var body: some View {
        NavigationLink {
            SettingsView()
        } label: {
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
                    Text("Pressure Off")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    (
                        Text("Go to ") +
                            Text("Settings").bold() +
                            Text(" and set your ") +
                            Text("Pressure level").bold() +
                            Text(" — ") +
                            Text("Standard").bold() +
                            Text(" or ") +
                            Text("Hardcore").bold() +
                            Text(" — to choose how serious accountability is.")
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
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .accessibilityLabel(
            "Pressure Off. Go to Settings to set pressure level Standard or Hardcore and choose how serious accountability is."
        )
    }
}

#Preview("Pressure Off card") {
    NavigationStack {
        PressureOffHomeCardView()
    }
    .environmentObject(AuthViewModel())
}
