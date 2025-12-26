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
    @StateObject private var friendsVM = FriendsViewModel()
    @State private var contacts: [CNContact] = []
    @State private var appUsers: [AppUserContact] = []
    @State private var selectedContacts: [CNContact] = []
    @State private var selectedAppUsers: [AppUserContact] = []
    @State private var showNoContactsAlert = false
    @State private var showNeedPermissionAlert = false
    @State private var isLoading = true
    
    private let firestoreService = FirestoreService()
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
                    .background(Color.white.cornerRadius(15))
                    .frame(width: 330, height: 430)
                
                if isLoading {
                    VStack {
                        Text("Loading contacts...")
                            .foregroundColor(.gray)
                        ProgressView()
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // App Users Section
                            if !appUsers.isEmpty {
                                Text("Friends on App")
                                    .font(.headline)
                                    .foregroundColor(primaryColor)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                
                                VStack(spacing: 12) {
                                    ForEach(appUsers, id: \.id) { appUserContact in
                                        AppUserCardView(
                                            appUserContact: appUserContact,
                                            isSelected: isAppUserSelected(appUserContact),
                                            onAdd: {
                                                addAppUser(appUserContact)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                                
                                Divider()
                                    .padding(.vertical, 8)
                            }
                            
                            // Other Contacts Section
                            Text("Invite Friends")
                                .font(.headline)
                                .foregroundColor(primaryColor)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            
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
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 12)
                    }
                    .frame(width: 320, height: 410)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
            }
            .frame(height: 430)
            
            Spacer()
            
            // "Not here? Invite" text
            Text("Not here? Invite")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            PrimaryButton(title: "Let's Begin") {
                Task { await addSelectedAsFriends() }
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
                    self.isLoading = false
                }
            }
        }
    }
    
    // Function to normalize phone numbers for consistent comparison
    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-numeric characters
        var normalized = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // If number starts with country code "1", remove it
        if normalized.hasPrefix("1") && normalized.count > 10 {
            // Remove the leading "1" if followed by a 10-digit number
            normalized = String(normalized.dropFirst())
        }
        
        // Return just the last 10 digits to handle any other country codes
        if normalized.count > 10 {
            normalized = String(normalized.suffix(10))
        }
        
        return normalized
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
                var phoneNumbers: [String] = []
                var phoneToContactMap: [String: CNContact] = [:]
                
                try contactStore.enumerateContacts(with: request) { contact, _ in
                    if !contact.phoneNumbers.isEmpty {
                        fetchedContacts.append(contact)
                        
                        // Extract phone numbers for app user check
                        for phoneNumber in contact.phoneNumbers {
                            // Format phone number to match database format
                            let formattedNumber = self.normalizePhoneNumber(phoneNumber.value.stringValue)
                            
                            // Add formatted phone number to the list
                            phoneNumbers.append(formattedNumber)
                            
                            // Map the formatted number to its contact
                            phoneToContactMap[formattedNumber] = contact
                        }
                    }
                }
                
                // Find app users among contacts
                self.firestoreService.fetchUsersByPhoneNumbers(phoneNumbers: phoneNumbers) { appUsers in
                    // Create mapping of app users to contacts
                    var appUserContacts: [AppUserContact] = []
                    var contactsToRemove: [String] = []
                    
                    // Get current user ID
                    let currentUserId = self.viewModel.currentUser?.id
                    
                    for appUser in appUsers {
                        // Skip if this is the current user
                        if appUser.id == currentUserId {
                            continue
                        }
                        
                        if let appUserPhone = appUser.phoneNumber {
                            let normalizedAppUserPhone = self.normalizePhoneNumber(appUserPhone)
                            
                            // Find matching contact using the normalized phone number
                            if let matchingContact = phoneToContactMap[normalizedAppUserPhone] {
                                // Create AppUserContact
                                let appUserContact = AppUserContact(
                                    id: UUID().uuidString,
                                    contact: matchingContact,
                                    user: appUser
                                )
                                appUserContacts.append(appUserContact)
                                
                                // Mark for removal from regular contacts
                                contactsToRemove.append(matchingContact.identifier)
                            }
                        }
                    }
                    
                    // Remove app users from regular contacts list
                    let filteredContacts = fetchedContacts.filter { contact in
                        !contactsToRemove.contains(contact.identifier)
                    }
                    
                    DispatchQueue.main.async {
                        self.contacts = filteredContacts
                        self.appUsers = appUserContacts
                        self.isLoading = false
                        
                        if filteredContacts.isEmpty && appUserContacts.isEmpty {
                            self.showNoContactsAlert = true
                        }
                    }
                }
            } catch {
                print("Error fetching contacts: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.showNoContactsAlert = true
                }
            }
        }
    }
    
    private func isContactSelected(_ contact: CNContact) -> Bool {
        return selectedContacts.contains(where: { $0.identifier == contact.identifier })
    }
    
    private func isAppUserSelected(_ appUserContact: AppUserContact) -> Bool {
        return selectedAppUsers.contains(where: { $0.id == appUserContact.id })
    }
    
    private func addContact(_ contact: CNContact) {
        if isContactSelected(contact) {
            selectedContacts.removeAll(where: { $0.identifier == contact.identifier })
        } else {
            selectedContacts.append(contact)
        }
    }
    
    private func addAppUser(_ appUserContact: AppUserContact) {
        if isAppUserSelected(appUserContact) {
            selectedAppUsers.removeAll(where: { $0.id == appUserContact.id })
        } else {
            selectedAppUsers.append(appUserContact)
        }
    }
    
    /// Onboarding "Find Friends" should register selected contacts as Friends (friend requests),
    /// not as `peerCoaches`.
    @MainActor
    private func addSelectedAsFriends() async {
        // Combine both lists and hand off to the same contacts → friends pipeline used by Friends tab.
        let combined = selectedContacts + selectedAppUsers.map { $0.contact }
        await friendsVM.addFriends(fromContacts: combined)
    }
    
    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// Helper struct to associate a contact with an app user
struct AppUserContact: Identifiable {
    var id: String
    var contact: CNContact
    var user: User
}

struct AppUserCardView: View {
    let appUserContact: AppUserContact
    let isSelected: Bool
    let onAdd: () -> Void
    
    private let cardBackground = Color("backgroundGray")
    private let primaryColor = Color("primaryColor")
    
    var body: some View {
        HStack {
            // Contact Avatar
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 40, height: 40)
                
                if let imageData = appUserContact.contact.thumbnailImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text(appUserContact.contact.givenName.prefix(1) + appUserContact.contact.familyName.prefix(1))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            // Contact Name
            VStack(alignment: .leading, spacing: 2) {
                Text("\(appUserContact.contact.givenName) \(appUserContact.contact.familyName)")
                    .font(.body)
                    .foregroundColor(.black)
                
                Text("Already using the app")
                    .font(.caption)
                    .foregroundColor(primaryColor)
            }
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

struct ContactCardView: View {
    let contact: CNContact
    let isSelected: Bool
    let onAdd: () -> Void
    
    private let cardBackground = Color("backgroundGray")
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
