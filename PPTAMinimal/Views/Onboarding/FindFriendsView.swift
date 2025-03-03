//
//  FindFriendsView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/2/25.
//

import SwiftUI
import Contacts
import ContactsUI

struct FindFriendsView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @EnvironmentObject var viewModel: AuthViewModel
    @ObservedObject var userSettingsManager = UserSettingsManager.shared
    @State private var contacts: [CNContact] = []
    @State private var selectedContacts: [CNContact] = []
    @State private var showNoContactsAlert = false
    @State private var showNeedPermissionAlert = false
    
    private let primaryColor = Color("primaryColor")
    private let cardBackground = Color(red: 0.9, green: 0.9, blue: 0.9)
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack(spacing: 8) {
                Text("Find Friends")
                    .font(.largeTitle)
                    .fontWeight(.medium)
                    .foregroundColor(primaryColor)
                
                Text("🤝")
                    .font(.largeTitle)
            }
            .padding(.top, 20)
            
            // Contacts List Container
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(.black, lineWidth: 1)
                    .background(Color.white)
                    .frame(width: 330, height: 415)
                
                if contacts.isEmpty {
                    VStack {
                        Text("Loading contacts...")
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(contacts, id: \.identifier) { contact in
                                ContactCardView(
                                    contact: contact,
                                    isSelected: isContactSelected(contact),
                                    onAdd: {
                                        addContact(contact)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(height: 400)
            
            Spacer()
            
            // "Not here? Invite" text
            Text("Not here? Invite")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            PrimaryButton(title: "Let's Begin") {
                saveSelectedContacts()
                coordinator.advance()
            }
            
            // Page indicator
            PageIndicator(page: 5)
                .padding(.bottom, 20)
        }
        .padding()
        .onAppear {
            requestContactsAccess()
        }
        .alert("Permission Required", isPresented: $showNeedPermissionAlert) {
            Button("OK", role: .cancel) { }
            Button("Open Settings") {
                openSettings()
            }
        } message: {
            Text("Please grant access to your contacts in Settings.")
        }
        .alert("No Contacts Found", isPresented: $showNoContactsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No contacts were found on your device.")
        }
    }
    
    private func requestContactsAccess() {
        let contactStore = CNContactStore()
        contactStore.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.fetchContacts()
                } else {
                    self.showNeedPermissionAlert = true
                }
            }
        }
    }
    
    private func fetchContacts() {
        let contactStore = CNContactStore()
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactThumbnailImageDataKey,
            CNContactIdentifierKey
        ] as [CNKeyDescriptor]
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                var fetchedContacts: [CNContact] = []
                
                try contactStore.enumerateContacts(with: request) { contact, _ in
                    if !contact.phoneNumbers.isEmpty {
                        fetchedContacts.append(contact)
                    }
                }
                
                DispatchQueue.main.async {
                    if fetchedContacts.isEmpty {
                        self.showNoContactsAlert = true
                    } else {
                        self.contacts = fetchedContacts
                    }
                }
            } catch {
                print("Error fetching contacts: \(error)")
                DispatchQueue.main.async {
                    self.showNoContactsAlert = true
                }
            }
        }
    }
    
    private func isContactSelected(_ contact: CNContact) -> Bool {
        return selectedContacts.contains(where: { $0.identifier == contact.identifier })
    }
    
    private func addContact(_ contact: CNContact) {
        if isContactSelected(contact) {
            selectedContacts.removeAll(where: { $0.identifier == contact.identifier })
        } else {
            selectedContacts.append(contact)
        }
    }
    
    private func saveSelectedContacts() {
        // Convert CNContacts to PeerCoach model
        let peerCoaches = selectedContacts.map { contact in
            let phoneNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
            return PeerCoach(
                givenName: contact.givenName,
                familyName: contact.familyName,
                phoneNumber: phoneNumber
            )
        }
        
        // Save to UserSettings
        UserSettingsManager.shared.loadSettings { currentSettings in
            var updatedSettings = currentSettings
            updatedSettings.peerCoaches.append(contentsOf: peerCoaches)
            
            DispatchQueue.main.async {
                UserSettingsManager.shared.saveSettings(updatedSettings)
            }
        }
    }
    
    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

struct ContactCardView: View {
    let contact: CNContact
    let isSelected: Bool
    let onAdd: () -> Void
    
    private let cardBackground = Color(red: 0.9, green: 0.9, blue: 0.9)
    private let primaryColor = Color("primaryColor")
    
    var body: some View {
        HStack {
            // Contact Avatar
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 40, height: 40)
                
                if let imageData = contact.thumbnailImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text(contact.givenName.prefix(1) + contact.familyName.prefix(1))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            // Contact Name
            Text("\(contact.givenName) \(contact.familyName)")
                .font(.body)
                .foregroundColor(.black)
                .padding(.leading, 8)
            
            Spacer()
            
            // Add Button
            Button(action: onAdd) {
                ZStack {
                    Circle()
                        .fill(primaryColor)
                        .frame(width: 28, height: 28)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    FindFriendsView(coordinator: OnboardingCoordinator())
}
