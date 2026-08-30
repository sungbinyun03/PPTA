//
//  OnboardingScaffold.swift
//  PPTAMinimal
//
//  The single layout every onboarding screen is built on.
//
//  Before this existed, each step re-declared its own VStack, its own paddings, and its own
//  hardcoded `PageIndicator(page:length:)`. The screens drifted apart visually and adding a step
//  meant editing all of them. Everything shared now lives here; a screen supplies only its
//  illustration, its words, and — when it needs one — a custom middle section.
//

import SwiftUI

struct OnboardingScaffold<Content: View>: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    /// Asset name. Rendered as a template image and tinted with `primaryColor`, so the artwork
    /// adapts to dark mode on its own — this is what replaced `.invertedForDarkMode()`, which
    /// could only ever produce pure white line art on a dark background.
    var illustration: String?
    var illustrationHeight: CGFloat = 250

    let title: String
    var message: String?

    let primaryTitle: String
    var primaryDisabled: Bool = false
    let onPrimary: () -> Void

    var secondaryTitle: String?
    var onSecondary: (() -> Void)?

    private let content: Content

    init(
        coordinator: OnboardingCoordinator,
        illustration: String? = nil,
        illustrationHeight: CGFloat = 250,
        title: String,
        message: String? = nil,
        primaryTitle: String,
        primaryDisabled: Bool = false,
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil,
        onPrimary: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.coordinator = coordinator
        self.illustration = illustration
        self.illustrationHeight = illustrationHeight
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.primaryDisabled = primaryDisabled
        self.secondaryTitle = secondaryTitle
        self.onSecondary = onSecondary
        self.onPrimary = onPrimary
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    if let illustration {
                        Image(illustration)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color("primaryColor"))
                            .frame(maxHeight: illustrationHeight)
                            .padding(.horizontal, 40)
                            .padding(.top, 24)
                            .padding(.bottom, 28)
                    }

                    VStack(spacing: 10) {
                        Text(title)
                            .font(.custom("BambiBold", size: 28))
                            .foregroundColor(Color("primaryColor"))
                            .multilineTextAlignment(.center)

                        if let message {
                            Text(message)
                                .font(.custom("Satoshi-Variable", size: 15))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 32)

                    content
                        .padding(.top, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 14) {
                PrimaryButton(title: primaryTitle, isDisabled: primaryDisabled, action: onPrimary)
                    .padding(.horizontal, 24)

                if let secondaryTitle, let onSecondary {
                    Button(action: onSecondary) {
                        Text(secondaryTitle)
                            .font(.custom("Satoshi-Variable", size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                PageIndicator(
                    page: coordinator.progressIndex,
                    length: coordinator.progressTotal
                )
                .padding(.top, 2)
                .padding(.bottom, 28)
            }
        }
    }
}

/// Convenience for screens that are illustration + words only.
///
/// A default argument can't be used for `content` on the main initialiser: Swift has nothing to
/// infer `Content` from when the argument is omitted, so it fails with "generic parameter 'Content'
/// could not be inferred". Constraining `Content == EmptyView` in an extension gives it the
/// concrete type instead.
extension OnboardingScaffold where Content == EmptyView {
    init(
        coordinator: OnboardingCoordinator,
        illustration: String? = nil,
        illustrationHeight: CGFloat = 250,
        title: String,
        message: String? = nil,
        primaryTitle: String,
        primaryDisabled: Bool = false,
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil,
        onPrimary: @escaping () -> Void
    ) {
        self.init(
            coordinator: coordinator,
            illustration: illustration,
            illustrationHeight: illustrationHeight,
            title: title,
            message: message,
            primaryTitle: primaryTitle,
            primaryDisabled: primaryDisabled,
            secondaryTitle: secondaryTitle,
            onSecondary: onSecondary,
            onPrimary: onPrimary,
            content: { EmptyView() }
        )
    }
}

#Preview {
    OnboardingScaffold(
        coordinator: OnboardingCoordinator(),
        illustration: "onb-the-key",
        title: "You set the limit.\nA friend holds the key.",
        message: "PPTA locks the apps you choose. Only your coach can let you back in.",
        primaryTitle: "Get Started",
        secondaryTitle: "Skip for now",
        onSecondary: {},
        onPrimary: {}
    )
}
