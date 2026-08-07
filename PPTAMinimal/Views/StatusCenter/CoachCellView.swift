//
//  CoachCellView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 14/10/25.
//

// ============================================================
// ⚠️  DEAD CODE — STATUS CENTER TAB REMOVED
// ============================================================
// This cell was only used inside StatusCenterView, which is no
// longer in the tab bar. Nothing in the active app references
// CoachCellView. Safe to delete.
// ============================================================

import SwiftUI

struct CoachCellView: View {
    private var name: String // TODO: Update once User and other fields get updated
    private var profilePicUrl: String?

    init(
        name: String,
        profilePicUrl: String? = nil
    ) {
        self.name = name
        self.profilePicUrl = profilePicUrl
    }

    var body: some View {
        HStack {
            InitialsProfilePicView(name: name, profilePicUrl: profilePicUrl, size: 65)
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    CoachCellView(name: "Peter Parker", profilePicUrl: "peter_parker")
}
