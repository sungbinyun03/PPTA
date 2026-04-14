//
//  NoTraineesHomeCardView.swift
//  PPTAMinimal
//
//  White bordered callout when the user has no trainees — nudges adding friends and requesting the Trainee role.
//

import SwiftUI

struct NoTraineesHomeCardView: View {
    /// Dark outline matching the home mock (subtle charcoal).
    private static let borderColor = Color(red: 0.25, green: 0.27, blue: 0.24)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.yellow)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 34))
                    .foregroundStyle(.black)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("No Trainees")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                (
                    Text("Add a friend").bold() +
                        Text(", and then ") +
                        Text("request they become your Trainee").bold() +
                        Text(" to start saving others!")
                )
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.88))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Self.borderColor.opacity(0.55), lineWidth: 3)
                )
        )
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }
}

#Preview("No Trainees card") {
    NavigationStack {
        NoTraineesHomeCardView()
    }
    .environmentObject(AuthViewModel())
}
