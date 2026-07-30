//
//  AvatarView.swift
//  PPTAMinimal
//

import SwiftUI

struct InitialsProfilePicView: View {
    let name: String
    let profilePicUrl: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let profilePicUrl, let url = URL(string: profilePicUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsCircle
                    }
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsCircle: some View {
        Circle()
            .fill(Color("primaryColor").opacity(0.12))
            .overlay(
                Text(initials(from: name))
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundColor(Color("primaryColor"))
            )
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}
