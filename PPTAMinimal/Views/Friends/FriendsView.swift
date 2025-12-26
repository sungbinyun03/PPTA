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
    @State private var phoneToAdd: String = ""
    @State private var isContactsImportPresented = false
    @State private var showContactsPermissionAlert = false
    @State private var selectedUserId: String? = nil
    @State private var showFriendProfile = false
    
    var body: some View {
        NavigationStack {
            VStack {
                ProfileView(headerPart1: "", headerPart2: "Friends", subHeader: "Where you'll find your people")
                
                VStack(spacing: 12) {
                    
                    HStack(spacing: 8) {
                        Button {
                            isContactsImportPresented = true
                        } label: {
                            Label("Add from Contacts", systemImage: "person.crop.circle.badge.plus")
                        }
                        .buttonStyle(.bordered)

                        TextField("Add by phone number (+1...)", text: $phoneToAdd)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            Task { await vm.addFriend(byPhone: phoneToAdd); phoneToAdd = "" }
                        }
                        .disabled(phoneToAdd.isEmpty)
                    }
                    
                    if let error = vm.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                    
                    List {
                        if !vm.incomingRequests.isEmpty {
                            Section("Requests") {
                                ForEach(vm.incomingRequests, id: \.friendship.id) { pair in
                                    Button {
                                        selectedUserId = pair.user.id
                                        showFriendProfile = true
                                    } label: {
                                        HStack {
                                            Text(pair.user.name)
                                            Spacer()
                                            Button("Accept") {
                                                Task { await vm.accept(pair.friendship.id) }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            Button("Decline") {
                                                Task { await vm.declineOrCancel(pair.friendship.id) }
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        if !vm.outgoingRequests.isEmpty {
                            Section("Pending") {
                                ForEach(vm.outgoingRequests, id: \.friendship.id) { pair in
                                    Button {
                                        selectedUserId = pair.user.id
                                        showFriendProfile = true
                                    } label: {
                                        HStack {
                                            Text(pair.user.name)
                                            Spacer()
                                            Text("Sent")
                                                .foregroundColor(.secondary)
                                            Button("Cancel") {
                                                Task { await vm.declineOrCancel(pair.friendship.id) }
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Section("Friends") {
                            if vm.friends.isEmpty {
                                Text("No friends yet.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(vm.friends, id: \.id) { friend in
                                    Button {
                                        selectedUserId = friend.id
                                        showFriendProfile = true
                                    } label: {
                                        HStack {
                                            Text(friend.name)
                                            Spacer()
                                            Text(friend.email)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                .padding(.horizontal)
                .task { await vm.refresh() }
                .refreshable { await vm.refresh() }
            }
        }
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

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// Allows for preview by disabling or replacing all the iPhone-only functionality
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
    }
}
