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
| Friend request received | `New friend request! 👋` | `Sam sent you a friend request.` |
| Friend request accepted | `Friend request accepted! 🎉` | `Sam accepted your friend request.` |
| Role request received | `New role request! 🤝` | `Sam wants to be your coach.` / `…your trainee.` |
| Role request accepted | `Request accepted! 🎉` | `Sam accepted your coach request.` / `…trainee request.` |

## Decisions

- 2026-10-11: Friend requests moved to the `role-requests` service with push notifications.

## Where it lives

- `cloudrunfunctions/role-requests.js` (`sendAlertPush` calls); app fallback in
  `PPTAMinimal/PPTAMinimalApp.swift`.

## Open questions

- Should a declined request notify the requester?
