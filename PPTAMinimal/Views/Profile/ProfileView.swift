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
            HStack(spacing: 15) {
                Text(user.intiials)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color(.systemGray3))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 4)
                    
                    Text(user.email)
                        .font(.footnote)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                Button {
                    viewModel.signOut()
                } label: {
                    SettingsRowView(imageName: "arrow.left.circle.fill",
                                    title: "Sign Out",
                                    tintColor: .red)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
