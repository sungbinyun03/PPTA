//
//  SettingsView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 3/1/25.
//  Updated 2025‑05‑20 – adds profile‑picture picker & upload flow
//

import SwiftUI
import PhotosUI
import FirebaseStorage

struct SettingsView: View {
    // MARK: – Dependencies
    @EnvironmentObject var viewModel: AuthViewModel
    @ObservedObject private var settingsMgr = UserSettingsManager.shared
    
    // MARK: – Local state
    @State private var selectedTab   = "Settings"
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading   = false
    @State private var uploadError:  String?
    
    // MARK: – View body
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                profileSection
                inviteBanner
                tabSelector
                settingsContent
            }
            .padding()
            // iOS 17+ onChange (two‑parameter variant)
            .onChange(of: pickerItem) { _, newItem in
                guard let item = newItem else { return }
                isUploading = true
                Task {
                    pickerItem = nil                      // clear selection ASAP
                    await uploadProfileImage(from: item)  // async helper below
                    await MainActor.run { isUploading = false }
                }
            }
            // simple alert on upload failure
            .alert("Upload failed",
                   isPresented: .constant(uploadError != nil)) {
                Button("OK") { uploadError = nil }
            } message: {
                Text(uploadError ?? "")
            }
        }
    }
    
    // MARK: – Profile picture upload helper
    private func uploadProfileImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            uploadError = "Could not read image data."
            return
        }
        
        do {
            let uid = viewModel.currentUser?.id ?? UUID().uuidString   // fallback
            let ref = Storage.storage()
                .reference(withPath: "profilePictures/\(uid).jpg")
            
            _ = try await ref.putDataAsync(data, metadata: nil)
            let url = try await ref.downloadURL()
            
            await UserSettingsManager.shared.update { settings in
                settings.profileImageURL = url
            }
                        
        } catch {
            uploadError = error.localizedDescription
        }
    }
    
    // MARK: – UI building blocks
    private var profileSection: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .strokeBorder(Color(red: 0.266, green: 0.337, blue: 0.180), lineWidth: 6)
                    .frame(width: 130, height: 130)
                
                avatarImage                                   // computed below
                
                if isUploading {                              // progress spinner
                    ProgressView().scaleEffect(1.2)
                }
            }
            // “Change Photo” overlay becomes a PhotosPicker button
            .overlay(changePhotoButton.offset(y: 60))
            
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.currentUser?.name ?? "User")
                    .font(.custom("BambiBold", size: 22))
                    .fontWeight(.bold)
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text("Edit your profile")
                            .font(.custom("SatoshiVariable-Bold_Light", size: 14))
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(6)
                    .background(
                        Color(red: 0.521, green: 0.651, blue: 0.423).opacity(0.1)
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .offset(x: -20)
        .padding(.bottom)
    }
    
    /// Avatar that shows either the stored profile picture or the default icon
    private var avatarImage: some View {
        if let url = settingsMgr.userSettings.profileImageURL {
            return AnyView(
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                    } else if phase.error != nil {
                        Image(systemName: "person.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                    }
                }
                .scaledToFill()
                .frame(width: 118, height: 118)
                .clipShape(Circle())
            )
        } else {
            return AnyView(
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.gray)
            )
        }
    }
    
    private var changePhotoButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Text("Change Photo")
                .font(.custom("SatoshiVariable-Bold_Light", size: 14))
                .padding(4)
                .background(Color(red: 0.4392, green: 0.4784, blue: 0.3843))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
    }
        
    private var inviteBanner: some View {
        HStack(alignment: .center) {
            Image(systemName: "person.3.fill")
                .foregroundColor(.gray)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading) {
                Text("Don't let your friends scroll endlessly alone!")
                    .font(.custom("SatoshiVariable-Bold_Bold", size: 12))
                    .lineLimit(1)
                    .fontWeight(.bold)
                Text("Invite 3 friends to unlock full features and hold each other accountable—because self-control is a team sport!")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray, lineWidth: 1)
        )
    }
    
    private var tabSelector: some View {
        HStack {
            ForEach(["Settings", "Friends"], id: \.self) { tab in
                VStack {
                    Text(tab)
                        .fontWeight(selectedTab == tab ? .bold : .regular)
                        .foregroundColor(selectedTab == tab ? .black : .gray)
                        .onTapGesture { selectedTab = tab }
                    
                    Rectangle()
                        .frame(height: 3)
                        .foregroundColor(selectedTab == tab ? .black : .clear)
                        .cornerRadius(2)
                }
                .frame(maxWidth: 120)
            }
        }
        .padding(.vertical)
        .frame(width: 250)
    }
    
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if selectedTab == "Settings" {
                NavigationLink(destination: AppSelectView()) {
                    settingsRow(icon: "app.badge", text: "Monitored Apps")
                }
                NavigationLink(destination: LimitSettingsView()) {
                    settingsRow(icon: "clock", text: "Limit Settings")
                }
                settingsRow(icon: "lock.shield", text: "Security")
                settingsRow(icon: "questionmark.circle", text: "Support")
            } else {
                FriendsView()
            }
        }
    }
    
    private func settingsRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
            Text(text)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        // .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
    }
}

// MARK: – Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthViewModel())
    }
}
