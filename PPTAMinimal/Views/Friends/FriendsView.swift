//
//  FriendsView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 6/11/25.
//

import SwiftUI
import Contacts
import UIKit

/// Identifies who the profile sheet should show, plus whatever the tapped row
/// already has in memory so `FriendProfileSheetView` can render instantly.
private struct FriendProfileTarget: Identifiable {
    let id: String
    let name: String
    let profilePicUrl: URL?
}

struct FriendsView: View {
    @StateObject private var vm = FriendsViewModel()
    @EnvironmentObject private var roleInbox: RoleRequestsInboxViewModel
    @EnvironmentObject private var statusCenter: StatusCenterViewModel
    @State private var phoneToAdd: String = ""
    @State private var isContactsImportPresented = false
    @State private var showContactsPermissionAlert = false
    @State private var profileTarget: FriendProfileTarget? = nil
    @State private var showFriendsInfo = false
    /// The phone-number field uses `.phonePad`, which has no Return/Done key, so focus is tracked
    /// here and cleared by a tap anywhere outside the keyboard (see the tap gesture below).
    @FocusState private var phoneFieldFocused: Bool
    @State private var friendSearchText: String = ""
    /// Whether the compact search field is revealed. Starts collapsed — see `friendSearchField`
    /// for why this exists as a separate affordance from `FriendsContactsImportView`'s `.searchable`.
    @State private var isFriendSearchActive = false
    @FocusState private var friendSearchFieldFocused: Bool

    private let primaryColor = Color("primaryColor")

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProfileView(headerPart1: "", headerPart2: "Friends", subHeader: "Where you'll find your people")

                ScrollView {
                    VStack(spacing: 24) {

                        // MARK: Add friends
                        VStack(spacing: 10) {
                            Button {
                                isContactsImportPresented = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 15, weight: .medium))
                                    Text("Add from Contacts")
                                        .font(.system(size: 15, weight: .medium))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .opacity(0.35)
                                }
                                .foregroundColor(primaryColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(primaryColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            HStack(spacing: 8) {
                                TextField("Add by phone number", text: $phoneToAdd)
                                    .keyboardType(.phonePad)
                                    .focused($phoneFieldFocused)
                                    .font(.system(size: 15))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(primaryColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Button {
                                    Task { await vm.addFriend(byPhone: phoneToAdd); phoneToAdd = "" }
                                } label: {
                                    Text("Add")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(phoneToAdd.isEmpty ? Color.gray.opacity(0.35) : primaryColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .disabled(phoneToAdd.isEmpty)
                            }

                            if let error = vm.errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.footnote)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // MARK: Role Requests
                        if !roleInbox.incoming.isEmpty {
                            sectionBlock(title: "Role Requests") {
                                ForEach(roleInbox.incoming) { pair in
                                    requestCard(
                                        name: pair.user.name,
                                        subtitle: roleRequestSubtitle(role: pair.request.role),
                                        onTap: { profileTarget = FriendProfileTarget(id: pair.user.id, name: pair.user.name, profilePicUrl: nil) },
                                        onAccept: { Task { await roleInbox.accept(pair.id) } },
                                        onDecline: { Task { await roleInbox.decline(pair.id) } }
                                    )
                                }
                            }
                        }

                        // MARK: Incoming Friend Requests
                        if !vm.incomingRequests.isEmpty {
                            sectionBlock(title: "Requests") {
                                ForEach(vm.incomingRequests, id: \.friendship.id) { pair in
                                    requestCard(
                                        name: pair.user.name,
                                        subtitle: nil,
                                        onTap: { profileTarget = FriendProfileTarget(id: pair.user.id, name: pair.user.name, profilePicUrl: nil) },
                                        onAccept: { Task { await vm.accept(pair.friendship.id) } },
                                        onDecline: { Task { await vm.declineOrCancel(pair.friendship.id) } }
                                    )
                                }
                            }
                        }

                        // MARK: Pending Outgoing (friend + coach/trainee requests)
                        if !vm.outgoingRequests.isEmpty || !roleInbox.outgoing.isEmpty {
                            sectionBlock(title: "Pending") {
                                ForEach(vm.outgoingRequests, id: \.friendship.id) { pair in
                                    pendingCard(
                                        name: pair.user.name,
                                        subtitle: "Friend request",
                                        onTap: { profileTarget = FriendProfileTarget(id: pair.user.id, name: pair.user.name, profilePicUrl: nil) },
                                        onCancel: { Task { await vm.declineOrCancel(pair.friendship.id) } }
                                    )
                                }
                                ForEach(roleInbox.outgoing) { pair in
                                    pendingCard(
                                        name: pair.user.name,
                                        subtitle: outgoingRoleSubtitle(role: pair.request.role),
                                        onTap: { profileTarget = FriendProfileTarget(id: pair.user.id, name: pair.user.name, profilePicUrl: nil) },
                                        onCancel: { Task { if let id = pair.request.id { await roleInbox.cancel(id) } } }
                                    )
                                }
                            }
                        }

                        // MARK: Friends
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Text("Friends")
                                    .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                                if vm.friends.isEmpty {
                                    Button { showFriendsInfo = true } label: {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.orange)
                                    }
                                    .buttonStyle(.plain)
                                    .popover(isPresented: $showFriendsInfo) {
                                        Text("Add a friend to get started. Friends can become your coaches or trainees.")
                                            .font(.subheadline)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(16)
                                            .frame(width: 260)
                                            .presentationCompactAdaptation(.popover)
                                    }
                                }

                                Spacer()

                                // Icon-only reveal, not an always-visible bar: the contacts import
                                // sheet one tap away already owns a full-width `.searchable`, so a
                                // second bar here read as duplicate chrome. Collapsing back to just
                                // this icon happens from inside `friendSearchField` (see its trailing
                                // button), which is also where `friendSearchText` gets reset.
                                if !vm.friends.isEmpty && !isFriendSearchActive {
                                    Button {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            isFriendSearchActive = true
                                        }
                                        friendSearchFieldFocused = true
                                    } label: {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(primaryColor.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)

                            // Search sits *inside* the Friends section, not above the whole
                            // screen, so it reads as scoped to this list. The request and
                            // Pending sections stay unfiltered — they're short, actionable, and
                            // already hide themselves when empty, so filtering them would make
                            // an Accept/Decline row silently vanish while typing.
                            if isFriendSearchActive && !vm.friends.isEmpty {
                                friendSearchField
                                    .padding(.horizontal, 20)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            VStack(spacing: 8) {
                                if vm.friends.isEmpty {
                                    Text("No friends yet")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 20)
                                } else if filteredFriends.isEmpty {
                                    Text("No friends match \u{201C}\(trimmedFriendQuery)\u{201D}")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 20)
                                } else {
                                    ForEach(filteredFriends, id: \.id) { friend in
                                        friendRow(friend: friend)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            // `.phonePad` has no Return key, so let a tap anywhere outside the field dismiss the
            // keyboard. `simultaneousGesture` + `contentShape` keeps buttons/rows still tappable.
            // Also drops focus from the friend search field on the same tap — it only ever
            // resigns keyboard focus here, never collapses the field itself or touches
            // `friendSearchText`, so it can't fight the field's own reveal/dismiss state.
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                phoneFieldFocused = false
                friendSearchFieldFocused = false
            })
        }
        .task { await vm.refresh() }
        .refreshable { await vm.refresh() }
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
        .sheet(isPresented: $isContactsImportPresented) {
            FriendsContactsImportView()
        }
        // The listener only watches *pending incoming* requests, so changes the sheet makes to
        // an accepted friendship (unfriending, role changes) need an explicit refresh.
        .sheet(item: $profileTarget, onDismiss: { Task { await vm.refresh() } }) { target in
            FriendProfileSheetView(
                otherUserId: target.id,
                snapshot: .init(name: target.name, profilePicUrl: target.profilePicUrl?.absoluteString),
                receivedNotes: statusCenter.coachActions[target.id]?.receivedNotes ?? []
            )
        }
        .alert("Contacts Permission Required", isPresented: $showContactsPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") { openAppSettings() }
        } message: {
            Text("To add friends from your contacts, please allow access in Settings.")
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

    // MARK: - Request card (incoming friend or role request)

    @ViewBuilder
    private func requestCard(
        name: String,
        subtitle: String?,
        onTap: @escaping () -> Void,
        onAccept: @escaping () -> Void,
        onDecline: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            InitialsProfilePicView(name: name, profilePicUrl: nil, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(action: onDecline) {
                    Text("Decline")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }

                Button(action: onAccept) {
                    Text("Accept")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(primaryColor)
                        .clipShape(Capsule())
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(primaryColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Pending card (outgoing request)

    @ViewBuilder
    private func pendingCard(
        name: String,
        subtitle: String? = nil,
        onTap: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            InitialsProfilePicView(name: name, profilePicUrl: nil, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Plain text, no pill — it's a status label, not a button.
            Text("Pending")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(primaryColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Friend search

    /// Hand-rolled rather than `.searchable()`: this tab's `NavigationStack` has no title bar for
    /// a system search field to attach to, and the chrome matches the phone field above. Revealed
    /// by the magnifier icon in the Friends header rather than shown always-on, so it doesn't read
    /// as a second copy of `FriendsContactsImportView`'s full-width `.searchable` bar one tap away.
    ///
    /// The trailing button is clear-then-collapse: with text typed it just empties the field
    /// (list stays visibly filterable); tapped again with nothing left to clear, it's the field's
    /// only dismiss path, so it collapses `isFriendSearchActive` and hands focus back. Because
    /// `friendSearchText` is always already empty by the time that collapse fires, no filter is
    /// ever left silently applied on a hidden field.
    private var friendSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(primaryColor.opacity(0.5))

            TextField("Search friends", text: $friendSearchText)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .focused($friendSearchFieldFocused)

            Button {
                if friendSearchText.isEmpty {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isFriendSearchActive = false
                    }
                    friendSearchFieldFocused = false
                } else {
                    friendSearchText = ""
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(primaryColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var trimmedFriendQuery: String {
        friendSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Matches on `name` only — it's the one field a friend row shows, so a hit on a hidden field
    /// (email, phone) would look like a bug. `localizedStandardContains` gets case- and
    /// diacritic-insensitive matching, and substrings so a surname matches mid-name.
    private var filteredFriends: [User] {
        let query = trimmedFriendQuery
        guard !query.isEmpty else { return vm.friends }
        return vm.friends.filter { $0.name.localizedStandardContains(query) }
    }

    // MARK: - Friend row

    @ViewBuilder
    private func friendRow(friend: User) -> some View {
        Button {
            profileTarget = FriendProfileTarget(id: friend.id, name: friend.name, profilePicUrl: vm.friendProfileImageURLs[friend.id])
        } label: {
            HStack(spacing: 12) {
                InitialsProfilePicView(name: friend.name, profilePicUrl: vm.friendProfileImageURLs[friend.id]?.absoluteString, size: 40)

                Text(friend.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(primaryColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func roleRequestSubtitle(role: RoleRequestRole) -> String {
        switch role {
        case .coach: return "Wants to be your coach"
        case .trainee: return "Wants to be your trainee"
        }
    }

    /// Label for a role request *I* sent. `role` is my requested role toward them, so `.trainee`
    /// (I want to be their trainee → they'd be my coach) reads as a "Coach request", and vice versa.
    private func outgoingRoleSubtitle(role: RoleRequestRole) -> String {
        switch role {
        case .trainee: return "Coach request"
        case .coach:   return "Trainee request"
        }
    }
}

struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        let auth = AuthViewModel()
        auth.currentUser = User(
            id: "preview-user",
            name: "Preview Name",
            email: "preview@example.com"
        )
        return FriendsView()
            .environmentObject(auth)
            .environmentObject(RoleRequestsInboxViewModel())
            .environmentObject(StatusCenterViewModel())
    }
}
