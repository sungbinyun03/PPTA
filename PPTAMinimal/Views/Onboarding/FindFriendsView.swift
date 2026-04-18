import SwiftUI
import Contacts
import ContactsUI

struct FindFriendsView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @EnvironmentObject var viewModel: AuthViewModel
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Find Friends")
                    .font(.custom("BambiBold", size: 32))
                    .foregroundColor(primaryColor)
                Text("Connect with people you know.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Contacts list
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(primaryColor.opacity(0.06))

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(primaryColor)
                        Text("Loading contacts...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if !appUsers.isEmpty {
                                Text("On PPTA")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(primaryColor.opacity(0.6))
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)

                                VStack(spacing: 8) {
                                    ForEach(appUsers, id: \.id) { appUserContact in
                                        AppUserCardView(
                                            appUserContact: appUserContact,
                                            isSelected: isAppUserSelected(appUserContact),
                                            onAdd: { addAppUser(appUserContact) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 12)

                                Divider()
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                            }

                            if !contacts.isEmpty {
                                Text("Invite Friends")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(primaryColor.opacity(0.6))
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 16)
                                    .padding(.top, appUsers.isEmpty ? 16 : 0)
                                    .padding(.bottom, 8)

                                VStack(spacing: 8) {
                                    ForEach(contacts, id: \.identifier) { contact in
                                        ContactCardView(
                                            contact: contact,
                                            isSelected: isContactSelected(contact),
                                            onAdd: { addContact(contact) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 20)

            // Bottom actions
            VStack(spacing: 12) {
                ShareLink(item: "Join me on PPTA – Peer Pressure The App!") {
                    Text("Not here? Invite a friend")
                        .font(.subheadline)
                        .foregroundColor(primaryColor)
                }
                .padding(.top, 12)

                PrimaryButton(title: "Let's Begin") {
                    Task {
                        await addSelectedAsFriends()
                        coordinator.advance()
                    }
                }
                .padding(.horizontal, 24)

                PageIndicator(page: 4, length: 5)
                    .padding(.bottom, 36)
            }
        }
        .onAppear { requestContactsAccess() }
        .alert("Permission Required", isPresented: $showNeedPermissionAlert) {
            Button("OK", role: .cancel) { }
            Button("Open Settings") { openSettings() }
        } message: {
            Text("Please grant access to your contacts in Settings.")
        }
        .alert("No Contacts Found", isPresented: $showNoContactsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No contacts were found on your device.")
        }
    }

    // MARK: - Private helpers

    private func requestContactsAccess() {
        let contactStore = CNContactStore()
        contactStore.requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async {
                if granted { self.fetchContacts() }
                else { self.showNeedPermissionAlert = true; self.isLoading = false }
            }
        }
    }

    private func fetchContacts() {
        let contactStore = CNContactStore()
        let keysToFetch = [
            CNContactGivenNameKey, CNContactFamilyNameKey,
            CNContactPhoneNumbersKey, CNContactThumbnailImageDataKey, CNContactIdentifierKey
        ] as [CNKeyDescriptor]

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                var fetchedContacts: [CNContact] = []
                var phoneNumbers: [String] = []
                var phoneToContactMap: [String: CNContact] = [:]

                try contactStore.enumerateContacts(with: request) { contact, _ in
                    guard !contact.phoneNumbers.isEmpty else { return }
                    fetchedContacts.append(contact)
                    for phone in contact.phoneNumbers {
                        let normalized = UserRepository.normalizePhoneNumber(phone.value.stringValue)
                        phoneNumbers.append(normalized)
                        phoneToContactMap[normalized] = contact
                    }
                }

                self.firestoreService.fetchUsersByAnyPhoneNumbers(phoneNumbers: phoneNumbers) { appUsers in
                    var appUserContacts: [AppUserContact] = []
                    var contactsToRemove: [String] = []
                    let currentUserId = self.viewModel.currentUser?.id

                    for appUser in appUsers {
                        guard appUser.id != currentUserId, let phone = appUser.phoneNumber else { continue }
                        let normalized = UserRepository.normalizePhoneNumber(phone)
                        if let match = phoneToContactMap[normalized] {
                            appUserContacts.append(AppUserContact(id: UUID().uuidString, contact: match, user: appUser))
                            contactsToRemove.append(match.identifier)
                        }
                    }

                    let filteredContacts = fetchedContacts.filter { !contactsToRemove.contains($0.identifier) }

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
                DispatchQueue.main.async { self.isLoading = false; self.showNoContactsAlert = true }
            }
        }
    }

    private func isContactSelected(_ contact: CNContact) -> Bool {
        selectedContacts.contains(where: { $0.identifier == contact.identifier })
    }

    private func isAppUserSelected(_ appUserContact: AppUserContact) -> Bool {
        selectedAppUsers.contains(where: { $0.id == appUserContact.id })
    }

    private func addContact(_ contact: CNContact) {
        if isContactSelected(contact) { selectedContacts.removeAll(where: { $0.identifier == contact.identifier }) }
        else { selectedContacts.append(contact) }
    }

    private func addAppUser(_ appUserContact: AppUserContact) {
        if isAppUserSelected(appUserContact) { selectedAppUsers.removeAll(where: { $0.id == appUserContact.id }) }
        else { selectedAppUsers.append(appUserContact) }
    }

    @MainActor
    private func addSelectedAsFriends() async {
        let combined = selectedContacts + selectedAppUsers.map { $0.contact }
        await friendsVM.addFriends(fromContacts: combined)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Supporting types

struct AppUserContact: Identifiable {
    var id: String
    var contact: CNContact
    var user: User
}

struct AppUserCardView: View {
    let appUserContact: AppUserContact
    let isSelected: Bool
    let onAdd: () -> Void

    private let primaryColor = Color("primaryColor")

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                if let data = appUserContact.contact.thumbnailImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Text((appUserContact.contact.givenName.prefix(1) + appUserContact.contact.familyName.prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(primaryColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(appUserContact.contact.givenName) \(appUserContact.contact.familyName)")
                    .font(.body)
                    .foregroundColor(.primary)
                Text("On PPTA")
                    .font(.caption)
                    .foregroundColor(primaryColor.opacity(0.8))
            }

            Spacer()

            Button(action: onAdd) {
                ZStack {
                    Circle()
                        .fill(isSelected ? primaryColor : primaryColor.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: isSelected ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? .white : primaryColor)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(primaryColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ContactCardView: View {
    let contact: CNContact
    let isSelected: Bool
    let onAdd: () -> Void

    private let primaryColor = Color("primaryColor")

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                if let data = contact.thumbnailImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Text((contact.givenName.prefix(1) + contact.familyName.prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(primaryColor)
                }
            }

            Text("\(contact.givenName) \(contact.familyName)")
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Button(action: onAdd) {
                ZStack {
                    Circle()
                        .fill(isSelected ? primaryColor : primaryColor.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: isSelected ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? .white : primaryColor)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(primaryColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    FindFriendsView(coordinator: OnboardingCoordinator())
}
