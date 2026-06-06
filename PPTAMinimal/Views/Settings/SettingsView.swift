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
    @State private var selectedTab     = "Settings"
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading     = false
    @State private var uploadError:    String?
    @State private var isEditingName   = false
    @State private var editedName      = ""
    @State private var isSavingName    = false

    @Environment(\.openURL) private var openURL
    
    // MARK: – View body
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                profileSection
                Divider()
                // TODO: Uncomment the inviteBanner once we have the functionality implemented
                // inviteBanner 
                settingsContent
                Spacer()
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
            .appAlert(
                isPresented: .init(
                    get: { uploadError != nil },
                    set: { if !$0 { uploadError = nil } }
                ),
                title: "Upload failed",
                message: uploadError ?? ""
            )
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
                    .strokeBorder(Color("primaryColor"), lineWidth: 6)
                    .frame(width: 130, height: 130)
                
                avatarImage                                   // computed below
                
                if isUploading {                              // progress spinner
                    ProgressView().scaleEffect(1.2)
                }
            }
            // “Change Photo” overlay becomes a PhotosPicker button
            .overlay(changePhotoButton.offset(y: 60))
            
            VStack(alignment: .leading, spacing: 12) {
                if isEditingName {
                    TextField("Your name", text: $editedName)
                        .font(.custom("BambiBold", size: 20))
                        .foregroundColor(Color("primaryColor"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color("primaryColor").opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            isEditingName = false
                            editedName = ""
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        Button(isSavingName ? "Saving..." : "Save") {
                            guard !isSavingName else { return }
                            let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            isSavingName = true
                            Task {
                                await viewModel.updateUserDisplayName(displayName: trimmed)
                                isSavingName = false
                                isEditingName = false
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color("primaryColor"))
                        .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingName)
                    }
                } else {
                    HStack(spacing: 6) {
                        Text(viewModel.currentUser?.name ?? "User")
                            .font(.custom("BambiBold", size: 22))
                            .fontWeight(.bold)
                        Button {
                            editedName = viewModel.currentUser?.name ?? ""
                            isEditingName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color("primaryColor").opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
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
                .background(Color("primaryColor"))
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
                NavigationLink(destination: AppLimitsView()) {
                    settingsRow(
                        icon: Image(systemName: "clock.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color("primaryColor"))
                            .scaleEffect(0.35),
                        text: "App Limits",
                        iconScale: 2
                    )
                }
                NavigationLink(destination: PressureLevelView()) {
                    settingsRow(
                        icon: Image(systemName: "gauge.with.dots.needle.33percent")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color("primaryColor"))
                            .scaleEffect(0.35),
                        text: "Pressure Level",
                        iconScale: 2
                    )
                }
                Button {
                    if let url = URL(string: "https://forms.gle/YOUR_FORM_ID") {
                        openURL(url)
                    }
                } label: {
                    settingsRow(icon: Image(systemName: "questionmark.circle"), text: "Support", iconScale: 1.2)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    viewModel.signOut()
                } label: {
                    settingsRow(icon: Image(systemName: "rectangle.portrait.and.arrow.right").offset(x:0.5), text: "Log Out", iconScale: 1.1)
                }
            } else {
                FriendsView()
            }
        }
    }
    
    /// Fixed icon slot — same for all rows so layout and row height stay uniform.
    private static let settingsRowIconSlotWidth: CGFloat = 44
    private static let settingsRowIconSlotHeight: CGFloat = 32

    /// iconScale: draw the icon larger/smaller inside the same slot (1.0 = default; e.g. 1.4 = 40% larger). Layout unchanged.
    private func settingsRow<Icon: View>(icon: Icon, text: String, iconScale: CGFloat = 1.0) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Column 1: fixed-size slot; iconScale only changes how big the image draws (clipped to slot)
            icon
                .scaleEffect(iconScale)
                .frame(width: Self.settingsRowIconSlotWidth, height: Self.settingsRowIconSlotHeight)
                .clipped()
            // Column 2: label
            Text(text)
                .foregroundColor(.primary)
            // Column 3: chevron (Spacer pushes it to trailing)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
    }
}

// MARK: – Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthViewModel())
    }
}
