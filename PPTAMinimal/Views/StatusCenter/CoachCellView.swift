//
//  CoachCellView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 14/10/25.
//

import SwiftUI

struct CoachCellView: View {
    private var name: String // TODO: Update once User and other fields get updated
    private var isCutOff: Bool
    private var profilePicUrl: String?
    
    var onRequestMercy: (() -> Void)? = nil // TODO: Wire up for the appropriate action

    init(
        name: String,
        isCutOff: Bool,
        profilePicUrl: String? = nil
    ) {
        self.name = name
        self.isCutOff = isCutOff
        self.profilePicUrl = profilePicUrl
    }

    var body: some View {
        HStack {
            Image(profilePicUrl ?? "google-icon") // TODO: Make this a button so that it goes to the user's profile
                .resizable()
                .scaledToFill()
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
                    Spacer()
                }
                
                // Bottom row: buttons
                HStack(spacing: 10) {
                    Button(action: { if canRequestMercy { onRequestMercy?() } }) {
                        Text("Request Mercy")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                            .frame(minWidth: 160)
                            .foregroundColor(cutOffTextColor)
                            .background(cutOffBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(!canRequestMercy)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Buttons state and appearance
    private var canRequestMercy: Bool { isCutOff }

    private var cutOffBackground: Color { canRequestMercy ? Color("primaryButtonColor") : Color(.systemGray5) }
    private var cutOffTextColor: Color { canRequestMercy ? .white : Color(.gray) }
}

#Preview {
    CoachCellView(name: "Peter Parker", isCutOff: true, profilePicUrl: "peter_parker")
}
