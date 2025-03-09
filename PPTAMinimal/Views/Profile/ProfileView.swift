//
//  ProfileView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 1/20/25.
//
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: AuthViewModel

    var body: some View {
        if let user = viewModel.currentUser {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text(user.intiials)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Color(.systemGray3))
                        .clipShape(Circle())
                        .offset(y: -4) // Moves the circle slightly higher
                    
                    VStack(alignment: .leading, spacing: 6) {
                        let fullName = viewModel.currentUser?.name ?? "User"
                        let firstName = fullName.components(separatedBy: " ").first ?? fullName

                        // Welcome Message with Custom Font
                        (Text("Welcome Back, ") +
                             Text("\(firstName)").font(.custom("BambiBold", size: 20)) +
                             Text("!").font(.system(size: 20, weight: .bold)))
                            .font(.custom("BambiBold", size: 18))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)

                            Text("Ready for another study session?")
                                .font(.custom("SatoshiVariable-Bold_Light", size: 14))
                                .foregroundStyle(Color(.darkGray))                    }
                }

                // Longer Divider
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1)
                    .frame(maxWidth: .infinity) // Extends the divider across the width
                    .padding(.horizontal, -16) // Extends slightly beyond normal padding
            }
            .padding(.horizontal, 24) // Keeps the main layout structured
        }
    }
}

#Preview {
    ProfileView()
}
