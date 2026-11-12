# Backend deploy pipeline

The five Cloud Run functions (`lockapp`, `unlockapp`, `statusupdate`, `role-requests`,
`deleteaccount`) deploy automatically from `main`. Full operating notes: `cloudrunfunctions/README.md`.

## Behaviour

- Cloud Build trigger `ppta-functions` (project `ppta-3a347`, region `us-central1`) runs on every push
  to `main` that touches `cloudrunfunctions/`.
- It runs the Python and Node tests; only if both pass does it deploy, in three batches:
  `statusupdate` + `lockapp`, then `unlockapp` + `role-requests`, then `deleteaccount`. A failure
  stops the batches after it.
- Before and after each deploy of `lockapp`, `unlockapp` and `statusupdate`, `deploy.sh` checks that
  the `UNLOCK_SECRET` env var is still set (by name, never printing the value).
- Build status shows as ✅/❌ next to the commit on GitHub; logs are in Cloud Build → History
  (region us-central1).
- A full deploy takes about 3 minutes.

## Decisions

- 2026-10-27: Deploy from `main` via Cloud Build; never edit source in the console.
- 2026-11-10: The key check uses `grep`, not `python3` (Google's `cloud-sdk:slim` image dropped it).
- 2026-11-11: Deploys run in three batches; five at once exceeded Cloud Build's 60-per-minute
  status-read quota.

## Incidents

- 2026-11-07 to 2026-11-11: the project's billing account was suspended, the project was shut down
  and every function returned 500. Fixed by restoring the project and relinking billing account
  `01F430-8C8FE0-474B3B`.

## Where it lives

- `cloudrunfunctions/deploy/cloudbuild.yaml`, `cloudrunfunctions/deploy/deploy.sh`,
  `cloudrunfunctions/deploy/<service>/` (pinned dependencies), `cloudrunfunctions/README.md`.

## Open questions

- Separate test services, or a test-branch trigger, so changes can be tried without deploying to
  live testers.
