# Friends and roles

Users add each other as friends, then ask a friend to be their coach or trainee.

## Behaviour

- Friend and role requests go through the `role-requests` Cloud Run service, which sends a push to
  the other person (works with the app closed).
- Ending a relationship or unfriending is silent.
- Declining a request is silent (not decided otherwise).

## Copy

| When | Title | Body |
|---|---|---|
| Friend request received | `Friend Request` | `Sam Trainee sent you a friend request. 👋` |
| Friend request accepted | `Friend Request` | `Sam Trainee accepted your friend request! 🎉` |
| Wants to be your coach | `Coach Request` | `Sam Trainee wants to be your coach. 🤝` |
| Wants to be your trainee | `Trainee Request` | `Sam Trainee wants to be your trainee. 🤝` |
| Coach request accepted | `Coach Request` | `Sam Trainee accepted your coach request! 🎉` |
| Trainee request accepted | `Trainee Request` | `Sam Trainee accepted your trainee request! 🎉` |

## Decisions

- 2026-10-11: Friend requests moved to the `role-requests` service with push notifications.
- 2026-11-11: Request notifications use a fixed title (`Friend Request`, `Coach Request`, `Trainee Request`) and name the person (full name) in the body.

## Where it lives

- `cloudrunfunctions/role-requests.js` (`sendAlertPush` calls); app fallback in
  `PPTAMinimal/PPTAMinimalApp.swift`.

## Open questions

- Should a declined request notify the requester?
