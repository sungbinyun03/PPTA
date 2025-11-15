//
//  FriendsView.swift
//  PPTAMinimal
//
//  Created by Assistant on 11/11/25.
//

import SwiftUI

struct FriendsView: View {
    @StateObject private var vm = FriendsViewModel()
    @State private var phoneToAdd: String = ""
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Friends")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            HStack(spacing: 8) {
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
                    }
                }
                
                if !vm.outgoingRequests.isEmpty {
                    Section("Pending") {
                        ForEach(vm.outgoingRequests, id: \.friendship.id) { pair in
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
                    }
                }
                
                Section("Friends") {
                    if vm.friends.isEmpty {
                        Text("No friends yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(vm.friends, id: \.id) { friend in
                            HStack {
                                Text(friend.name)
                                Spacer()
                                Text(friend.email)
                                    .foregroundColor(.secondary)
                            }
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


