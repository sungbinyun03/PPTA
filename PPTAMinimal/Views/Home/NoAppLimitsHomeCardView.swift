//
//  NoAppLimitsHomeCardView.swift
//  PPTAMinimal
//
//  Olive “No App Limits” callout when `UserSettings.hasViableAppLimits` is false.
//

import SwiftUI

struct NoAppLimitsHomeCardView: View {
    /// Muted olive / sage (home mock): readable white text on top.
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
                    Image(systemName: "clock.fill")
                        .font(.title2)
                        .foregroundStyle(Color.blue)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("No App Limits")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    (
                        Text("Go to ") +
                            Text("Settings").bold() +
                            Text(", and ") +
                            Text("set your Time Limits").bold() +
                            Text(" and ") +
                            Text("Apps to Limit").bold() +
                            Text(" to begin your journey!")
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
        .accessibilityLabel("No App Limits. Go to Settings to set time limits and apps to limit.")
    }
}

#Preview("No App Limits card") {
    NavigationStack {
        NoAppLimitsHomeCardView()
    }
    .environmentObject(AuthViewModel())
}
