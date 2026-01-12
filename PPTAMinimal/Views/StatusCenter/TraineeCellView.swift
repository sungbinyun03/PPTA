//
//  TraineeCellView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 14/10/25.
//

import SwiftUI

struct TraineeCellView: View {
    private var name: String // TODO: Update once User and other fields get updated
    private var status: TraineeStatus
    private var profilePicUrl: String?

    var onCutOff: (() -> Void)? = nil // TODO: Wire up for the appropriate action
    var onRelease: (() -> Void)? = nil

    init(
        name: String,
        status: TraineeStatus,
        profilePicUrl: String? = nil,
        onCutOff: (() -> Void)? = nil,
        onRelease: (() -> Void)? = nil
    ) {
        self.name = name
        self.status = status
        self.profilePicUrl = profilePicUrl
        self.onCutOff = onCutOff
        self.onRelease = onRelease
    }

    var body: some View {
        HStack {
            Group {
                if let profilePicUrl, let url = URL(string: profilePicUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image("google-icon").resizable().scaledToFill()
                        }
                    }
                } else {
                    Image("google-icon").resizable().scaledToFill()
                }
            }
                .frame(width: 65, height: 65)
                .clipShape(Circle())
            VStack(spacing: 12) {
                // Top row: avatar + name + small status dot
                HStack(alignment: .center, spacing: 12) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 16, height: 16)
                }
                
                // Bottom row: buttons
                HStack(spacing: 10) {
                    Button(action: { if canCutOff { onCutOff?() } }) {
                        Text("Cut Off")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(cutOffTextColor)
                            .background(cutOffBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(!canCutOff)
                    
                    Button(action: { if canRelease { onRelease?() } }) {
                        Text("Release")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(releaseTextColor)
                            .background(releaseBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(!canRelease)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Status mapping
    private var statusDotColor: Color {
        switch status {
        case .allClear: return .green
        case .attentionNeeded: return .red
        case .cutOff: return Color(white: 0.25)
        case .noStatus: return .clear
        }
    }

    // MARK: - Buttons state and appearance
    private var canCutOff: Bool { status == .attentionNeeded }
    private var canRelease: Bool { status == .cutOff }

    private var cutOffBackground: Color { canCutOff ? Color("primaryButtonColor") : Color(.systemGray5) }
    private var cutOffTextColor: Color { canCutOff ? .white : Color(.gray) }

    private var releaseBackground: Color { canRelease ? Color("primaryButtonColor") : Color(.systemGray5) }
    private var releaseTextColor: Color { canRelease ? .white : Color(.gray) }
}

#Preview {
    TraineeCellView(name: "Peter Parker", status: .attentionNeeded, profilePicUrl: "peter_parker")
}
