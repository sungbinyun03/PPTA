//
//  CoachCellView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 14/10/25.
//

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
