//
//  FriendsView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 6/11/25.
//

import SwiftUI
import Contacts
import UIKit

struct FriendsView: View {
    @StateObject private var vm = FriendsViewModel()
    @EnvironmentObject private var roleInbox: RoleRequestsInboxViewModel
    @State private var phoneToAdd: String = ""
    @State private var isContactsImportPresented = false
    @State private var showContactsPermissionAlert = false
    @State private var selectedUserId: String? = nil
    @State private var showFriendProfile = false

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
                                        onTap: { selectedUserId = pair.user.id; showFriendProfile = true },
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
                                        onTap: { selectedUserId = pair.user.id; showFriendProfile = true },
                                        onAccept: { Task { await vm.accept(pair.friendship.id) } },
                                        onDecline: { Task { await vm.declineOrCancel(pair.friendship.id) } }
                                    )
                                }
                            }
                        }

                        // MARK: Pending Outgoing
                        if !vm.outgoingRequests.isEmpty {
                            sectionBlock(title: "Pending") {
                                ForEach(vm.outgoingRequests, id: \.friendship.id) { pair in
                                    pendingCard(
                                        name: pair.user.name,
                                        onTap: { selectedUserId = pair.user.id; showFriendProfile = true },
                                        onCancel: { Task { await vm.declineOrCancel(pair.friendship.id) } }
                                    )
                                }
                            }
                        }

                        // MARK: Friends
                        sectionBlock(title: "Friends") {
                            if vm.friends.isEmpty {
                                Text("No friends yet")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            } else {
                                ForEach(vm.friends, id: \.id) { friend in
                                    friendRow(friend: friend)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .task { await vm.refresh() }
        .refreshable { await vm.refresh() }
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
        .sheet(isPresented: $isContactsImportPresented) {
            FriendsContactsImportView()
        }
        .sheet(isPresented: $showFriendProfile) {
            if let id = selectedUserId {
                FriendProfileSheetView(otherUserId: id)
            }
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
        HStack(spacing: 12) {
            initialsCircle(name: name, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(primaryColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Pending card (outgoing request)

    @ViewBuilder
    private func pendingCard(
        name: String,
        onTap: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            initialsCircle(name: name, size: 40)

            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Text("Pending")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.systemGray5))
                .clipShape(Capsule())

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

    // MARK: - Friend row

    @ViewBuilder
    private func friendRow(friend: User) -> some View {
        Button {
            selectedUserId = friend.id
            showFriendProfile = true
        } label: {
            HStack(spacing: 12) {
                initialsCircle(name: friend.name, size: 40)

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
    }
}
