//
//  BrandHeader.swift
//  PPTAMinimal
//

import SwiftUI

/// The sign-in branding (title + tagline), optionally with the app icon above it. Shared by
/// `LoginView` (no icon) and `LaunchFacadeView` (icon) so the two never drift.
struct BrandHeader: View {
    /// Side of the app icon tile; `nil` shows the text only.
    var iconSize: CGFloat? = nil

    private let primaryColor = Color("primaryColor")

    var body: some View {
        VStack(spacing: 16) {
            if let iconSize {
                Image("launch_logo")
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.2237, style: .continuous))
            }
            VStack(spacing: 8) {
                Text("PPTA")
                    .font(.custom("BambiBold", size: 52))
                    .foregroundColor(primaryColor)
                Text("Peer Pressure The App")
                    .font(.custom("Satoshi-Variable", size: 15))
                    .foregroundColor(primaryColor.opacity(0.6))
            }
        }
    }
}
