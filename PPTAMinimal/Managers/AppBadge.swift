//
//  AppBadge.swift
//  PPTAMinimal
//
//  The red count on PPTA's app icon: how many things are waiting on this user. Same items as the
//  server's `badgeCountFor` (cloudrunfunctions/badge.js), which every push carries so the icon is
//  right while PPTA is closed:
//    - trainees in attentionNeeded,
//    - trainees cut off and asking me for more time,
//    - incoming friend requests and incoming coach/trainee requests.
//
//  While PPTA is open, `TabNavigator` sets it from its live lists. A silent push sets it from its
//  `badge` data value (an alert push carries `aps.badge`, which iOS applies itself).
//

import UserNotifications

enum AppBadge {
    /// The total from what the app has loaded. Mirrors badge.js `needsCoach`.
    static func count(trainees: [StatusCenterPerson], incomingFriendRequests: Int, incomingRoleRequests: Int) -> Int {
        let waitingTrainees = trainees.filter(isWaitingOnMe).count
        return waitingTrainees + incomingFriendRequests + incomingRoleRequests
    }

    /// Needs attention, or cut off and asking me for more time.
    private static func isWaitingOnMe(_ person: StatusCenterPerson) -> Bool {
        switch person.traineeStatus {
        case .attentionNeeded: return true
        case .cutOff: return person.isRequestingSnoozeFromMe
        default: return false
        }
    }

    static func set(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(max(0, count)) { error in
            if let error { print("AppBadge: couldn't set badge: \(error)") }
        }
    }

    /// The total a push carried in its data (`"badge": "3"`), if any.
    static func count(fromPush userInfo: [AnyHashable: Any]) -> Int? {
        guard let raw = userInfo["badge"] as? String else { return nil }
        return Int(raw)
    }
}
