# App icon badge

The red count on PPTA's home-screen icon: how many things are waiting on the user.

## Behaviour

- Counts, for this user:
  - trainees who **need attention** (they can be locked),
  - trainees **cut off and asking this user for more time**,
  - incoming **friend requests** and incoming **coach/trainee requests**.
- 0 hides the badge. Sign-out clears it.
- **PPTA open:** set live from the same lists as the Home and Friends tab badges.
- **PPTA closed:** every push the server sends carries the user's current total, so any push sets the
  icon to the right number, down as well as up. Alert pushes carry it in `aps.badge` (iOS applies it
  even when PPTA is force-quit); silent pushes carry it in `data.badge` and the app sets it when woken.
- **Known gap:** something resolved with no push to this user (someone cancels a request they sent)
  leaves the number too high until their next push or until they open PPTA. A trainee going back to
  all clear (including the midnight reset) sends their coaches a silent push, which fixes the count
  unless the coach force-quit PPTA (iOS doesn't wake a force-quit app for silent pushes).

## Decisions

- 2026-11-15: Badge carried on existing pushes (no new service). A `badge-sync` Firestore-triggered
  function that pushes on every change was considered; deferred until stale counts are a problem.

## Where it lives

- Server: `cloudrunfunctions/badge.js` (`badgeCountFor`), used by `statusupdate.js` and
  `role-requests.js`; `deploy/deploy.sh` stages it next to both.
- App: `PPTAMinimal/Managers/AppBadge.swift`; set in `Views/TabNavigator.swift`, from pushes in
  `PPTAMinimalApp.swift`, cleared in `AuthViewModel.signOut`.

## Open questions

- `badge-sync` (see `.omc/plans/app-icon-badge.md`) if the known gap matters in practice.
