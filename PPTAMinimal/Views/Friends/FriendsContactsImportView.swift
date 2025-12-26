//
//  FriendsContactsImportView.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/20/25.
//

import SwiftUI
import Contacts
import UIKit
import MessageUI

struct FriendsContactsImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var friendsVM = FriendsViewModel()

    @State private var isLoading = true
    @State private var showNeedPermissionAlert = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var messageDraft: MessageDraft? = nil
    @State private var showCannotSendMessageAlert = false

    @State private var onApp: [RegisteredContact] = []
    @State private var invite: [ContactRow] = []
    @State private var errorMessage: String? = nil

    private let firestoreService = FirestoreService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Scanning your contacts…")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if let errorMessage {
                            Section {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.footnote)
                            }
                        }

                        if !onApp.isEmpty {
                            Section("On Peer Pressure") {
                                ForEach(onApp) { item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.displayName)
                                            Text(item.user.email)
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        trailingAction(for: item)
                                    }
                                }
                            }
                        }

                        Section("Invite to Peer Pressure") {
                            if invite.isEmpty {
                                Text("No other contacts found with phone numbers.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(invite) { c in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(c.displayName)
                                            if let phone = c.primaryPhone {
                                                Text(phone)
                                                    .font(.footnote)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Button("Invite") {
                                            presentInvite(for: c)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Add from Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                requestContactsAccessAndLoad()
                Task { await refreshFriendshipState() }
            }
            .alert("Contacts Permission Required", isPresented: $showNeedPermissionAlert) {
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Open Settings") { openSettings() }
            } message: {
                Text("To find friends from your contacts, please allow access in Settings.")
            }
            .alert("Messages Unavailable", isPresented: $showCannotSendMessageAlert) {
                Button("OK", role: .cancel) { }
                Button("Share Instead") {
                    showShareSheet = true
                }
            } message: {
                Text("This device can’t send text messages. You can still share an invite another way.")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
            .sheet(item: $messageDraft) { draft in
                MessageComposeView(recipients: draft.recipients, body: draft.body)
            }
        }
    }

    // MARK: - Friendship state helpers (drive Add/Sent/Accept/Friends buttons)

    private func trailingAction(for item: RegisteredContact) -> some View {
        let uid = item.user.id

        if let incoming = friendsVM.incomingRequests.first(where: { $0.user.id == uid }) {
            return AnyView(
                Button("Accept") {
                    Task {
                        await friendsVM.accept(incoming.friendship.id)
                        await refreshFriendshipState()
                    }
                }
                .buttonStyle(.borderedProminent)
            )
        }

        if friendsVM.friends.contains(where: { $0.id == uid }) {
            return AnyView(
                Text("Friends")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            )
        }

        if friendsVM.outgoingRequests.contains(where: { $0.user.id == uid }) {
            return AnyView(
                Text("Sent")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            )
        }

        return AnyView(
            Button("Add") {
                Task {
                    await friendsVM.addFriend(userId: uid)
                    await refreshFriendshipState()
                }
            }
            .buttonStyle(.borderedProminent)
        )
    }

    @MainActor
    private func refreshFriendshipState() async {
        await friendsVM.refresh()
        errorMessage = friendsVM.errorMessage
    }

    // MARK: - Permissions + Loading

    private func requestContactsAccessAndLoad() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            load()
        case .notDetermined:
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    granted ? load() : showDenied()
                }
            }
        case .denied, .restricted:
            showDenied()
        @unknown default:
            showDenied()
        }
    }

    private func showDenied() {
        isLoading = false
        showNeedPermissionAlert = true
    }

    private func load() {
        isLoading = true

        let contactStore = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let request = CNContactFetchRequest(keysToFetch: keysToFetch)

                var allContacts: [ContactRow] = []
                var phoneNumbers: [String] = []
                var phoneToContact: [String: ContactRow] = [:]

                try contactStore.enumerateContacts(with: request) { contact, _ in
                    guard !contact.phoneNumbers.isEmpty else { return }

                    let phones = contact.phoneNumbers.map { $0.value.stringValue }
                    let row = ContactRow(
                        id: contact.identifier,
                        givenName: contact.givenName,
                        familyName: contact.familyName,
                        phoneNumbers: phones
                    )
                    allContacts.append(row)

                    for raw in phones {
                        let normalized = normalizePhoneNumber(raw)
                        if !normalized.isEmpty {
                            phoneNumbers.append(raw)
                            phoneToContact[normalized] = row
                        }
                    }
                }

                // Pre-lookup against Firebase to identify registered users in this contact list.
                firestoreService.fetchUsersByAnyPhoneNumbers(phoneNumbers: phoneNumbers) { users in
                    let currentUserId = friendsVM.currentUserId

                    var matched: [RegisteredContact] = []
                    var matchedContactIds = Set<String>()

                    for user in users {
                        if user.id == currentUserId { continue }
                        guard let phone = user.phoneNumber else { continue }
                        let normalized = normalizePhoneNumber(phone)
                        if let row = phoneToContact[normalized] {
                            matched.append(
                                RegisteredContact(
                                    id: "\(row.id)-\(user.id)",
                                    contact: row,
                                    user: user
                                )
                            )
                            matchedContactIds.insert(row.id)
                        }
                    }

                    let inviteList = allContacts
                        .filter { !matchedContactIds.contains($0.id) }
                        .sorted { $0.displayName < $1.displayName }

                    let onAppList = matched
                        .sorted { $0.displayName < $1.displayName }

                    DispatchQueue.main.async {
                        self.onApp = onAppList
                        self.invite = inviteList
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.onApp = []
                    self.invite = []
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Invite

    private func presentInvite(for contact: ContactRow) {
        let text = "Join me on Peer Pressure — let’s keep each other accountable."
        shareItems = [text]

        guard let phone = contact.primaryPhone else {
            print("FriendsContactsImportView.presentInvite: no phone for contact \(contact.displayName); falling back to ShareSheet")
            showShareSheet = true
            return
        }

        let sanitized = sanitizePhoneForMessaging(phone)
        print("FriendsContactsImportView.presentInvite:")
        print("  contact=\(contact.displayName)")
        print("  rawPhone=\(phone)")
        print("  sanitizedPhone=\(sanitized)")
        print("  canSendText=\(MFMessageComposeViewController.canSendText())")

        // Prefer an SMS composer with pre-filled recipient and body.
        if MFMessageComposeViewController.canSendText() {
            let draft = MessageDraft(recipients: [sanitized], body: text)
            print("  setting messageDraft.recipients=\(draft.recipients)")
            print("  setting messageDraft.body=\(draft.body)")
            messageDraft = draft
        } else {
            showCannotSendMessageAlert = true
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func sanitizePhoneForMessaging(_ phone: String) -> String {
        // MFMessageCompose is fairly permissive, but removing punctuation makes To: more reliable.
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
    }

    // MARK: - Phone normalization (must match FirestoreService logic)

    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        var normalized = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if normalized.hasPrefix("1") && normalized.count > 10 {
            normalized = String(normalized.dropFirst())
        }
        if normalized.count > 10 {
            normalized = String(normalized.suffix(10))
        }
        return normalized
    }
}

// MARK: - Models

struct MessageDraft: Identifiable {
    let id = UUID()
    let recipients: [String]
    let body: String
}

struct ContactRow: Identifiable {
    let id: String
    let givenName: String
    let familyName: String
    let phoneNumbers: [String]

    var displayName: String {
        let full = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return full.isEmpty ? "Unknown" : full
    }

    var primaryPhone: String? { phoneNumbers.first }
}

struct RegisteredContact: Identifiable {
    let id: String
    let contact: ContactRow
    let user: User

    var displayName: String { contact.displayName }
}


