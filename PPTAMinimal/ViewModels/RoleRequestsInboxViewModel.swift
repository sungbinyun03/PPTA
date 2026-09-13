//
//  RoleRequestsInboxViewModel.swift
//  PPTAMinimal
//
//  Created by Assistant on 1/12/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class RoleRequestsInboxViewModel: ObservableObject {
    struct IncomingPair: Identifiable {
        let request: RoleRequest
        let user: User

        var id: String {
            request.id ?? "\(request.requesterId)_\(request.targetId)_\(request.role.rawValue)"
        }
    }

    /// A pending role request *I* sent, paired with its target user (the person I asked). Powers the
    /// Friends-tab "Pending" rows for coach/trainee requests so status is visible without opening a card.
    struct OutgoingPair: Identifiable {
        let request: RoleRequest
        let user: User

        var id: String {
            request.id ?? "\(request.requesterId)_\(request.targetId)_\(request.role.rawValue)"
        }
    }

    @Published var incoming: [IncomingPair] = []
    @Published var outgoing: [OutgoingPair] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let roleRepo = RoleRequestRepository()
    private let userRepo = UserRepository()
    private var listener: ListenerRegistration?
    private var outgoingListener: ListenerRegistration?

    private var didPrimeListener = false
    private var seenIds = Set<String>()

    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    func refreshOnce() async {
        guard let uid = currentUserId else { return }
        do {
            let requests = try await roleRepo.fetchIncomingPending(for: uid)
            let pairs = try await buildIncomingPairs(requests: requests)
            await apply(pairs: pairs)
        } catch {
            errorMessage = error.localizedDescription
        }
        do {
            let requests = try await roleRepo.fetchOutgoingPending(for: uid)
            let pairs = try await buildOutgoingPairs(requests: requests)
            await applyOutgoing(pairs: pairs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startListening() {
        guard let uid = currentUserId else { return }

        // Incoming: role requests addressed to me.
        if listener == nil {
            let query = db.collection("roleRequests")
                .whereField("targetId", isEqualTo: uid)
                .whereField("status", isEqualTo: RoleRequestStatus.pending.rawValue)
                .order(by: "createdAt", descending: true)

            listener = query.addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor in self.errorMessage = error.localizedDescription }
                    return
                }
                let requests: [RoleRequest] = (snap?.documents ?? []).compactMap { try? $0.data(as: RoleRequest.self) }
                Task {
                    do {
                        let pairs = try await self.buildIncomingPairs(requests: requests)
                        await self.apply(pairs: pairs)
                    } catch {
                        await MainActor.run { self.errorMessage = error.localizedDescription }
                    }
                }
            }
        }

        // Outgoing: role requests I sent (pending).
        if outgoingListener == nil {
            let query = db.collection("roleRequests")
                .whereField("requesterId", isEqualTo: uid)
                .whereField("status", isEqualTo: RoleRequestStatus.pending.rawValue)
                .order(by: "createdAt", descending: true)

            outgoingListener = query.addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor in self.errorMessage = error.localizedDescription }
                    return
                }
                let requests: [RoleRequest] = (snap?.documents ?? []).compactMap { try? $0.data(as: RoleRequest.self) }
                Task {
                    do {
                        let pairs = try await self.buildOutgoingPairs(requests: requests)
                        await self.applyOutgoing(pairs: pairs)
                    } catch {
                        await MainActor.run { self.errorMessage = error.localizedDescription }
                    }
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        outgoingListener?.remove()
        outgoingListener = nil
        didPrimeListener = false
        seenIds.removeAll()
    }

    func accept(_ requestId: String) async {
        do {
            try await roleRepo.accept(id: requestId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func decline(_ requestId: String) async {
        do {
            try await roleRepo.decline(id: requestId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Cancels a role request *I* sent — used by the Friends-tab pending row.
    func cancel(_ requestId: String) async {
        do {
            try await roleRepo.cancel(id: requestId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func buildIncomingPairs(requests: [RoleRequest]) async throws -> [IncomingPair] {
        try await withThrowingTaskGroup(of: IncomingPair?.self) { group in
            for req in requests {
                group.addTask {
                    guard let user = try await self.userRepo.fetchUser(by: req.requesterId) else { return nil }
                    return IncomingPair(request: req, user: user)
                }
            }
            var out: [IncomingPair] = []
            for try await maybe in group {
                if let pair = maybe { out.append(pair) }
            }
            return out
        }
        .sorted { (a, b) in
            (a.request.createdAt ?? .distantPast) > (b.request.createdAt ?? .distantPast)
        }
    }

    private func buildOutgoingPairs(requests: [RoleRequest]) async throws -> [OutgoingPair] {
        try await withThrowingTaskGroup(of: OutgoingPair?.self) { group in
            for req in requests {
                group.addTask {
                    // Outgoing: the "other" person is the target of the request.
                    guard let user = try await self.userRepo.fetchUser(by: req.targetId) else { return nil }
                    return OutgoingPair(request: req, user: user)
                }
            }
            var out: [OutgoingPair] = []
            for try await maybe in group {
                if let pair = maybe { out.append(pair) }
            }
            return out
        }
        .sorted { (a, b) in
            (a.request.createdAt ?? .distantPast) > (b.request.createdAt ?? .distantPast)
        }
    }

    @MainActor
    private func apply(pairs: [IncomingPair]) {
        let ids = Set(pairs.map(\.id))
        let newlyAdded = ids.subtracting(seenIds)

        if didPrimeListener, let firstNewId = newlyAdded.first,
           let pair = pairs.first(where: { $0.id == firstNewId }) {
            let title = "New role request! 🤝"
            let body = roleRequestMessage(from: pair.user.name, role: pair.request.role)
            NotificationManager.shared.sendNotification(title: title, body: body)
        }

        seenIds = ids
        incoming = pairs
        didPrimeListener = true
    }

    @MainActor
    private func applyOutgoing(pairs: [OutgoingPair]) {
        // Notification-free: these are my own outgoing requests, not something to alert me about.
        outgoing = pairs
    }

    private func roleRequestMessage(from name: String, role: RoleRequestRole) -> String {
        let first = name.firstNameOnly
        switch role {
        case .coach:
            return "\(first) wants to be your coach."
        case .trainee:
            return "\(first) wants to be your trainee."
        }
    }
}
