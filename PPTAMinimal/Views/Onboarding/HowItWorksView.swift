//
//  HowItWorksView.swift
//  PPTAMinimal
//
//  Screen 2 of the fresh flow — the whole loop in five short steps, right after `IntroKeyView`
//  says what the app is for. Text only, no illustration: a numbered timeline reads faster than a
//  picture here, and every step is something the user is about to do in the screens that follow.
//

import SwiftUI

struct HowItWorksView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    /// True when pushed from Settings ("How It Works" row) rather than shown in onboarding: no
    /// button — the navigation Back button is the way out.
    var standalone: Bool = false

    private struct Step {
        let emoji: String
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(emoji: "⏱️",
             title: "Set your App Limits",
             detail: "Pick the apps to track and a daily time limit."),
        Step(emoji: "👋",
             title: "Add friends",
             detail: "Find them by phone number."),
        Step(emoji: "🤝",
             title: "Pair up",
             detail: "Open their profile and ask them to be your coach, your trainee, or both."),
        Step(emoji: "🔒",
             title: "Keep each other honest",
             detail: "Go over your limit and your coaches can lock your apps. When your trainees go over, it's your turn."),
        Step(emoji: "🛐",
             title: "Beg for mercy",
             detail: "Locked out? Ask a coach to snooze it for 10 minutes. Better make it a good excuse."),
    ]

    var body: some View {
        OnboardingScaffold(
            coordinator: coordinator,
            title: "How Peer Pressure Works",
            primaryTitle: standalone ? nil : "Next",
            onPrimary: { coordinator.advance() }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepRow(number: index + 1, step: step, isLast: index == steps.count - 1)
                }

                iconTip
                    .padding(.top, 28)
            }
            .padding(.horizontal, 32)
        }
    }

    /// Not a step — a note teaching the badges that appear around the app. Each icon is drawn the
    /// way it appears in the UI (same symbol, same status colour) so people recognise it later.
    private var iconTip: some View {
        let warning = Text(Image(systemName: "exclamationmark.circle.fill")).foregroundColor(.orange)
        let info = Text(Image(systemName: "questionmark.circle")).foregroundColor(Color("primaryColor"))
        let lock = Text(Image(systemName: "lock.fill")).foregroundColor(.red)
        let snooze = Text(Image(systemName: "hand.raised.fill"))
            .foregroundColor(TraineeStatus.snoozedLock.ringColor ?? .blue)

        return VStack(alignment: .leading, spacing: 6) {
            Text("Spot \(warning) \(info) \(lock) or \(snooze)?")
                .font(.custom("Satoshi-Variable", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text("Tap it! You'll find tips for using Peer Pressure, or messages from your coaches and trainees.")
                .font(.custom("Satoshi-Variable", size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color("primaryColor").opacity(0.1))
        )
        .accessibilityElement(children: .combine)
    }

    /// One timeline row: numbered badge with a connector running down to the next badge.
    private func stepRow(number: Int, step: Step, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Text("\(number)")
                    .font(.custom("BambiBold", size: 16))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color("primaryColor")))

                if !isLast {
                    Rectangle()
                        .fill(Color("primaryColor").opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(step.title) \(step.emoji)")
                    .font(.custom("Satoshi-Variable", size: 17))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(step.detail)
                    .font(.custom("Satoshi-Variable", size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 5)
            .padding(.bottom, isLast ? 0 : 22)

            Spacer(minLength: 0)
        }
        // Row height = the text's natural height, so the connector stretches to exactly reach
        // the next badge (the scaffold's ScrollView gives no fixed height to fill otherwise).
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

#Preview("How It Works") {
    HowItWorksView(coordinator: OnboardingCoordinator())
}

#Preview("How It Works · Dark") {
    HowItWorksView(coordinator: OnboardingCoordinator())
        .preferredColorScheme(.dark)
}
