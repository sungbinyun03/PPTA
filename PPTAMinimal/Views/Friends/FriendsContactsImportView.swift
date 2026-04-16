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
    private let primaryColor = Color("primaryColor")

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(primaryColor)
                        Text("Scanning your contacts…")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {

                            if let errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.footnote)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                            }

                            // MARK: On App
                            if !onApp.isEmpty {
                                sectionBlock(title: "On Peer Pressure") {
                                    ForEach(onApp) { item in
                                        contactRow(
                                            name: item.displayName,
                                            detail: item.contact.primaryPhone,
                                            trailing: { trailingAction(for: item) }
                                        )
                                    }
                                }
                            }

                            // MARK: Invite
                            sectionBlock(title: "Invite to Peer Pressure") {
                                if invite.isEmpty {
                                    Text("No other contacts found with phone numbers.")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 20)
                                } else {
                                    ForEach(invite) { c in
                                        contactRow(
                                            name: c.displayName,
                                            detail: c.primaryPhone,
                                            trailing: {
                                                Button("Invite") { presentInvite(for: c) }
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 7)
                                                    .background(Color(.systemGray5))
                                                    .clipShape(Capsule())
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Add from Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(primaryColor)
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
                Button("Share Instead") { showShareSheet = true }
            } message: {
                Text("This device can't send text messages. You can still share an invite another way.")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
            .sheet(item: $messageDraft) { draft in
                MessageComposeView(recipients: draft.recipients, body: draft.body)
            }
        }
    }

    // MARK: - Section builder

    @ViewBuilder
    private func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(primaryColor.opacity(0.6))
                .padding(.horizontal, 20)

            VStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Contact row

    @ViewBuilder
    private func contactRow<Trailing: View>(
        name: String,
        detail: String?,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            initialsCircle(name: name, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                if let detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(primaryColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Trailing action (friendship state-driven)

    @ViewBuilder
    private func trailingAction(for item: RegisteredContact) -> some View {
        let uid = item.user.id

        if let incoming = friendsVM.incomingRequests.first(where: { $0.user.id == uid }) {
            Button("Accept") {
                Task {
                    await friendsVM.accept(incoming.friendship.id)
                    await refreshFriendshipState()
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(primaryColor)
            .clipShape(Capsule())
        } else if friendsVM.friends.contains(where: { $0.id == uid }) {
            Text("Friends")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        } else if friendsVM.outgoingRequests.contains(where: { $0.user.id == uid }) {
            Text("Sent")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        } else {
            Button("Add") {
                Task {
                    await friendsVM.addFriend(userId: uid)
                    await refreshFriendshipState()
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(primaryColor)
            .clipShape(Capsule())
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func initialsCircle(name: String, size: CGFloat) -> some View {
        Circle()
            .fill(primaryColor.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                Text(initials(from: name))
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundColor(primaryColor)
            )
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
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
        let text = "Join me on Peer Pressure — let's keep each other accountable."
        shareItems = [text]

        guard let phone = contact.primaryPhone else {
            showShareSheet = true
            return
        }

        let sanitized = sanitizePhoneForMessaging(phone)

        if MFMessageComposeViewController.canSendText() {
            messageDraft = MessageDraft(recipients: [sanitized], body: text)
        } else {
            showCannotSendMessageAlert = true
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func sanitizePhoneForMessaging(_ phone: String) -> String {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
    }

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
