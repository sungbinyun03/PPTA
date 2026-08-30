//
//  PendingCoachRequestStore.swift
//  PPTAMinimal
//
//  Bridges the gap between "I asked someone to coach me" and "we are actually friends".
//
//  A role request cannot be sent to a stranger: `FriendProfileViewModel.buildCoachAction` and
//  `buildTraineeAction` both disable the action until an accepted friendship exists, and the
//  server enforces the same policy. Onboarding must not be the one place that violates it.
//
//  So when a user asks a brand-new contact to coach them, the friend request goes out immediately
//  and the coach request is parked here. It fires the moment the friendship is accepted —
//  `FriendsViewModel.acceptedListener` already watches for exactly that transition.
//

import Foundation
import FirebaseAuth

enum PendingCoachRequestStore {

    private static var key: String? {
        // Written out rather than `currentUser?.uid.map { ... }`: inside an optional chain the
        // `.map` binds to the unwrapped `String`, resolving to `Sequence.map` over its Characters
        // instead of `Optional.map`. The resulting type error is bad enough that the compiler
        // fails to diagnose it at all.
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return "pendingCoachRequests_\(uid)"
    }

    // MARK: - Queue

    static func pending() -> [String] {
        guard let key else { return [] }
        return UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func queue(_ targetId: String) {
        guard let key else { return }
        var current = pending()
        guard !current.contains(targetId) else { return }
        current.append(targetId)
        UserDefaults.standard.set(current, forKey: key)
    }

    static func remove(_ targetId: String) {
        guard let key else { return }
        UserDefaults.standard.set(pending().filter { $0 != targetId }, forKey: key)
    }

    static func clear() {
        guard let key else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Drain

    /// Foreground backstop: resolves the current friend list itself, then drains.
    ///
    /// `FriendsViewModel` drains on every `refresh()`, but only while a view holding one is alive.
    /// A friendship accepted while the app was closed would otherwise sit parked until the user
    /// happened to open Friends. Cheap to call — it returns immediately when the queue is empty.
    static func drainUsingCurrentFriendships() async {
        guard !pending().isEmpty, let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let accepted = try await FriendshipRepository().fetchAcceptedFriendships(for: uid)
            let ids = Set(accepted.map { $0.requesterId == uid ? $0.requesteeId : $0.requesterId })
            await drain(acceptedFriendIds: ids)
        } catch {
            print("PendingCoachRequestStore.drainUsingCurrentFriendships: \(error)")
        }
    }

    /// Fires the parked coach requests for everyone who has since become an accepted friend.
    ///
    /// The role is `.trainee`, not `.coach`. `RoleRequestRole` describes the **requester's** role,
    /// not the target's — see `RoleRequestRepository.removeRelationship`'s doc comment and
    /// `FriendProfileViewModel.performCoachPrimary()`, which sends `.trainee` for exactly this.
    /// Sending `.coach` here would ask to coach *them*, inverting every relationship the flow
    /// creates.
    ///
    /// Safe to call repeatedly: entries are dropped only on success or when the relationship
    /// already exists, and anything still awaiting acceptance stays queued.
    @discardableResult
    static func drain(acceptedFriendIds: Set<String>) async -> Int {
        let queued = pending()
        guard !queued.isEmpty else { return 0 }

        let repository = RoleRequestRepository()
        let existingCoaches = Set(UserSettingsManager.shared.userSettings.coachIds)

        var remaining: [String] = []
        var sent = 0

        for targetId in queued {
            // Already coaching me — the request landed and was accepted elsewhere.
            if existingCoaches.contains(targetId) { continue }

            // Not friends yet; keep waiting.
            guard acceptedFriendIds.contains(targetId) else {
                remaining.append(targetId)
                continue
            }

            do {
                _ = try await repository.createRoleRequest(targetId: targetId, role: .trainee)
                sent += 1
            } catch {
                // Transient failures (offline, server hiccup) must not silently drop the ask.
                print("PendingCoachRequestStore.drain: failed for \(targetId): \(error)")
                remaining.append(targetId)
            }
        }

        if let key {
            UserDefaults.standard.set(remaining, forKey: key)
        }
        return sent
    }
}
