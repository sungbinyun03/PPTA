//
//  CreateProfileView.swift
//  PPTAMinimal
//
//  Name + profile picture. Always shown — the name is pre-filled when sign-in (Apple / Google) or a
//  returning account already has one, so it's one tap; the picture is never supplied by sign-in.
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import UIKit

struct CreateProfileView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @ObservedObject private var settingsMgr = UserSettingsManager.shared
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var displayName: String = ""
    @State private var isSaving = false

    // Profile picture picked/uploaded right here, on the same screen as the name.
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    @State private var isUploadingPhoto = false

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespaces)
    }

    private var initials: String {
        let parts = trimmedName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        } else if let first = parts.first, !first.isEmpty {
            return String(first.prefix(2))
        }
        return ""
    }

    var body: some View {
        OnboardingScaffold(
            coordinator: coordinator,
            title: "What should we call you?",
            message: "This is the name your coaches and trainees will see.",
            primaryTitle: isSaving ? "Saving…" : "Next",
            primaryDisabled: trimmedName.isEmpty || isSaving,
            onPrimary: save
        ) {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    avatar
                    Text("Tap to add a photo (optional)")
                        .font(.custom("Satoshi-Variable", size: 12))
                        .foregroundColor(.secondary)
                }
                InputView(
                    text: $displayName,
                    title: "Display Name",
                    placeholder: "Your name"
                )
                .padding(.horizontal, 24)
            }
        }
        .onAppear(perform: prefill)
        .onChange(of: viewModel.currentUser) { _, _ in prefill() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run { pickedImageData = data }
                }
                await uploadProfileImage(from: item)
            }
        }
    }

    /// Tappable avatar: shows the just-picked image, then the stored one, then initials/placeholder.
    private var avatar: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack {
                Circle()
                    .fill(Color("primaryColor").opacity(0.12))
                    .frame(width: 116, height: 116)

                avatarContent

                if isUploadingPhoto {
                    ProgressView()
                        .tint(Color("primaryColor"))
                }

                // Camera badge, bottom-trailing.
                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color("primaryColor"))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .offset(x: 40, y: 40)
            }
        }
        .buttonStyle(.plain)
        .disabled(isUploadingPhoto)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let data = pickedImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 116, height: 116)
                .clipShape(Circle())
        } else if let url = settingsMgr.userSettings.profileImageURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholderAvatar
                }
            }
            .frame(width: 116, height: 116)
            .clipShape(Circle())
        } else {
            placeholderAvatar
        }
    }

    @ViewBuilder
    private var placeholderAvatar: some View {
        if initials.isEmpty {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(Color("primaryColor").opacity(0.4))
                .frame(width: 46, height: 46)
        } else {
            Text(initials.uppercased())
                .font(.custom("BambiBold", size: 38))
                .foregroundColor(Color("primaryColor"))
        }
    }

    /// Same upload path as Settings: Photos item → Firebase Storage → `profileImageURL`.
    private func uploadProfileImage(from item: PhotosPickerItem) async {
        await MainActor.run { isUploadingPhoto = true }
        defer { Task { @MainActor in isUploadingPhoto = false } }

        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        do {
            let uid = viewModel.currentUser?.id ?? UUID().uuidString
            let ref = Storage.storage().reference(withPath: "profilePictures/\(uid).jpg")
            _ = try await ref.putDataAsync(data, metadata: nil)
            let url = try await ref.downloadURL()
            await UserSettingsManager.shared.update { settings in
                settings.profileImageURL = url
            }
        } catch {
            // Non-blocking: the photo is optional, so a failed upload just leaves the placeholder.
        }
    }

    private func prefill() {
        guard displayName.isEmpty else { return }
        if let name = viewModel.currentUser?.name, !name.isEmpty, name != "Unknown" {
            displayName = name
        }
    }

    private func save() {
        isSaving = true
        Task {
            await viewModel.updateUserDisplayName(displayName: trimmedName)
            await MainActor.run {
                isSaving = false
                coordinator.advance()
            }
        }
    }
}

#Preview {
    CreateProfileView(coordinator: OnboardingCoordinator())
        .environmentObject(AuthViewModel())
}
