//
//  ProfileView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 1/20/25.
//
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @ObservedObject private var settingsMgr = UserSettingsManager.shared
    private var headerPart1: String
    private var headerPart2: String?
    private var subHeader: String
    
    init(headerPart1: String, headerPart2: String? = nil, subHeader: String) {
        self.headerPart1 = headerPart1
        self.headerPart2 = headerPart2
        self.subHeader = subHeader
    }

    var body: some View {
        if let user = viewModel.currentUser {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    NavigationLink(destination: SettingsView()) {
                        Group {
                            if let url = settingsMgr.userSettings.profileImageURL {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        initialsCircle(for: user)
                                    }
                                }
                                .frame(width: 58, height: 58)
                                .clipShape(Circle())
                            } else {
                                initialsCircle(for: user)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 20, height: 20)
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        let fullName = viewModel.currentUser?.name ?? "User"
                        let firstName = fullName.components(separatedBy: " ").first ?? fullName
                        let headerPart2ToShow = headerPart2?.isEmpty == false ? headerPart2! : firstName

                        // Welcome Message with Custom Font
                        (Text(headerPart1) +
                             Text("\(headerPart2ToShow)").font(.custom("BambiBold", size: 20)) +
                         (headerPart2?.isEmpty == false ? Text("") : Text("!").font(.system(size: 20, weight: .bold))))
                            .font(.custom("BambiBold", size: 18))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)

                        Text(subHeader)
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

    private func initialsCircle(for user: User) -> some View {
        Text(user.intiials)
            .font(.title)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(width: 58, height: 58)
            .background(Color(.systemGray3))
            .clipShape(Circle())
    }
}

// Allows for preview by disabling or replacing all the required iPhone-only functionality
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let auth = AuthViewModel()
        auth.currentUser = User(
            id: "preview-user",
            name: "Preview Name",
            email: "preview@example.com"
        )
        
        return ProfileView(headerPart1: "At the ", headerPart2: nil, subHeader: "Gotta be a sweat bro")
            .environmentObject(auth)
    }
}
