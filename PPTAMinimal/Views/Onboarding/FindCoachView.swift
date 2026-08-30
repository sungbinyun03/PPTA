//
//  FindCoachView.swift
//  PPTAMinimal
//
//  Screen 5 of 5 — the only step that needs another human.
//
//  The old `FindFriendsView` sent *friendship* requests and called it done. A friendship is not a
//  coaching relationship: the user then had to wait for an accept, find the person under Friends,
//  open their profile, and tap "Request as Coach" — a screen they had no reason to revisit. So the
//  one thing that makes the app work was buried two navigations deep and never mentioned.
//
//  Here one tap does both. If they're already a friend, the coach request goes out immediately.
//  If not, the friend request goes out and the coach request is parked in
//  `PendingCoachRequestStore` until the friendship is accepted.
//
//  Contacts access is requested from an explicit button, not from `.onAppear` — the old flow threw
//  the system dialog up the instant the screen loaded, with no explanation of why PPTA wanted an
//  address book.
//

import SwiftUI
import Contacts
import UIKit
import UserNotifications

struct FindCoachView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @EnvironmentObject var viewModel: AuthViewModel
    @StateObject private var friendsVM = FriendsViewModel()

    private enum Phase { case priming, loading, ready }

    @State private var phase: Phase = .priming
    @State private var appUsers: [User] = []
    @State private var requested: Set<String> = []
    @State private var contactsDenied = false
    @State private var didRequestNotifications = false

    private let firestoreService = FirestoreService()
    private let roleRequests = RoleRequestRepository()
    private let primaryColor = Color("primaryColor")

    private var inviteMessage: String {
        "Join me on PPTA — I need someone to hold me to my screen time limit."
    }

    var body: some View {
        OnboardingScaffold(
            coordinator: coordinator,
            illustration: phase == .priming ? "onb-find-coach" : nil,
            illustrationHeight: 220,
            title: "Who's holding your key?",
            message: message,
            primaryTitle: requested.isEmpty ? "Skip for now" : "Done",
            onPrimary: finish
        ) {
            switch phase {
            case .priming: primingActions
            case .loading: loadingState
            case .ready:   readyState
            }
        }
    }

    private var message: String {
        switch phase {
        case .priming:
            return "Pick someone who'll actually say no to you. Until a coach accepts, nobody can lock you — and nobody can let you back in."
        case .loading:
            return "Looking for people you know…"
        case .ready:
            return appUsers.isEmpty
                ? "Nobody in your contacts is on PPTA yet. Invite someone — you can add them as a coach once they join."
                : "They'll get a request. Once they accept, they can lock and release your apps."
        }
    }

    // MARK: - Phases

    private var primingActions: some View {
        VStack(spacing: 14) {
            Button(action: beginContactSearch) {
                Label("Find my friends", systemImage: "person.2.fill")
                    .font(.custom("Satoshi-Variable", size: 15))
                    .fontWeight(.semibold)
                    .foregroundColor(primaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(primaryColor.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Text("PPTA matches phone numbers to find people already using the app. Your contacts are never uploaded.")
                .font(.custom("Satoshi-Variable", size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if contactsDenied { deniedNotice }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(primaryColor)
            Text("Loading contacts…")
                .font(.custom("Satoshi-Variable", size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var readyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !appUsers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    kicker("On PPTA")
                    VStack(spacing: 8) {
                        ForEach(appUsers) { candidate in
                            coachRow(candidate)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                kicker(appUsers.isEmpty ? "Invite someone" : "Not here?")
                ShareLink(item: inviteMessage) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Invite a friend to PPTA")
                            .font(.custom("Satoshi-Variable", size: 15))
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(primaryColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(primaryColor.opacity(0.1))
                    )
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func coachRow(_ candidate: User) -> some View {
        let targetId = candidate.id
        let isRequested = requested.contains(targetId)
        let isAlreadyCoach = UserSettingsManager.shared.userSettings.coachIds.contains(targetId)

        return HStack(spacing: 12) {
            InitialsProfilePicView(
                name: candidate.name,
                profilePicUrl: nil,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.name)
                    .font(.custom("Satoshi-Variable", size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(isAlreadyCoach ? "Already your coach" : (isRequested ? "Requested" : "On PPTA"))
                    .font(.custom("Satoshi-Variable", size: 12))
                    .foregroundColor(primaryColor.opacity(0.8))
            }

            Spacer(minLength: 8)

            Button {
                ask(candidate)
            } label: {
                Text(isRequested || isAlreadyCoach ? "Sent" : "Ask to coach me")
                    .font(.custom("Satoshi-Variable", size: 13))
                    .fontWeight(.semibold)
                    .foregroundColor(isRequested || isAlreadyCoach ? .secondary : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            isRequested || isAlreadyCoach
                                ? Color(.systemGray5)
                                : primaryColor
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(isRequested || isAlreadyCoach)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(primaryColor.opacity(0.08))
        )
    }

    private var deniedNotice: some View {
        VStack(spacing: 8) {
            Text("PPTA can't see your contacts. You can still invite someone with a link.")
                .font(.custom("Satoshi-Variable", size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") { openSettings() }
                .font(.custom("Satoshi-Variable", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(primaryColor)
        }
        .padding(.horizontal, 32)
    }

    private func kicker(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.custom("Satoshi-Variable", size: 11))
            .fontWeight(.semibold)
            .tracking(1.2)
            .foregroundColor(primaryColor.opacity(0.6))
    }

    // MARK: - Actions

    private func beginContactSearch() {
        phase = .loading
        CNContactStore().requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async {
                guard granted else {
                    contactsDenied = true
                    phase = .ready
                    return
                }
                contactsDenied = false
                Task { await loadContacts() }
            }
        }
    }

    @MainActor
    private func loadContacts() async {
        // Friend lists must be loaded before matching, so an existing friend is offered the
        // immediate path rather than being queued behind a duplicate friend request.
        await friendsVM.refresh()
        fetchContacts()
    }

    private func fetchContacts() {
        // Read main-actor state before hopping to a background queue — the enumeration below runs
        // off-main and must not touch `viewModel`.
        let myId = viewModel.currentUser?.id
        let store = CNContactStore()
        let keys = [
            CNContactGivenNameKey, CNContactFamilyNameKey,
            CNContactPhoneNumbersKey, CNContactIdentifierKey
        ] as [CNKeyDescriptor]

        DispatchQueue.global(qos: .userInitiated).async {
            var phoneNumbers: [String] = []
            var phoneToContact: [String: CNContact] = [:]

            do {
                try store.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { contact, _ in
                    guard !contact.phoneNumbers.isEmpty else { return }
                    for phone in contact.phoneNumbers {
                        let normalized = UserRepository.normalizePhoneNumber(phone.value.stringValue)
                        phoneNumbers.append(normalized)
                        phoneToContact[normalized] = contact
                    }
                }
            } catch {
                print("FindCoachView: contact fetch failed: \(error)")
                DispatchQueue.main.async { phase = .ready }
                return
            }

            firestoreService.fetchUsersByAnyPhoneNumbers(phoneNumbers: phoneNumbers) { users in
                var matches: [User] = []
                var seenUserIds = Set<String>()

                for user in users {
                    guard user.id != myId, let phone = user.phoneNumber else { continue }
                    let normalized = UserRepository.normalizePhoneNumber(phone)
                    // Only surface people who are actually in this device's address book — a
                    // phone-number match against the whole user table would leak strangers.
                    guard phoneToContact[normalized] != nil else { continue }
                    guard !seenUserIds.contains(user.id) else { continue }
                    seenUserIds.insert(user.id)
                    matches.append(user)
                }

                DispatchQueue.main.async {
                    appUsers = matches
                    phase = .ready
                }
            }
        }
    }

    /// One tap = friend request + coach request, in whichever order the relationship allows.
    private func ask(_ candidate: User) {
        let targetId = candidate.id
        guard !requested.contains(targetId) else { return }
        requested.insert(targetId)

        Task {
            await requestNotificationsOnce()

            if friendsVM.friends.contains(where: { $0.id == targetId }) {
                // Already friends — the role request is allowed right now.
                do {
                    _ = try await roleRequests.createRoleRequest(targetId: targetId, role: .trainee)
                } catch {
                    print("FindCoachView: coach request failed for \(targetId): \(error)")
                    await MainActor.run { requested.remove(targetId) }
                }
                return
            }

            // Not friends yet. `sendFriendRequest` has no duplicate guard — it writes a new
            // document on every call — so skip it when a request is already in flight either way.
            let alreadyPending =
                friendsVM.outgoingRequests.contains { $0.user.id == targetId } ||
                friendsVM.incomingRequests.contains { $0.user.id == targetId }

            if !alreadyPending {
                await friendsVM.addFriend(userId: targetId)
            }
            PendingCoachRequestStore.queue(targetId)
        }
    }

    /// Notifications are asked for here rather than on their own screen: "we'll tell you when they
    /// accept" is the most concrete reason the user will ever have to say yes.
    private func requestNotificationsOnce() async {
        guard !didRequestNotifications else { return }
        didRequestNotifications = true
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    private func finish() {
        coordinator.advance()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    FindCoachView(coordinator: OnboardingCoordinator())
        .environmentObject(AuthViewModel())
}
