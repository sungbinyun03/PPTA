# cloudrunfunctions

Cloud Build deploys these functions from `main`. Nobody pastes into the console.

## What deploys and when
- Trigger `ppta-functions` fires on every push to `main` that touches `cloudrunfunctions/` (docs-only pushes are ignored).
  It runs the Python and Node tests, and only if both are green deploys **all five** functions in parallel.
- All five deploy every time so that main equals live by construction; a push can never leave a function on old code.
- `deploy/deploy.sh` stages `deploy/<service>/` (the pinned manifest) plus the function file and passes only the
  source. Env vars, secrets, identity, access and scaling stay as they are on the live service. Never add a flag for them.
- unlockapp alone deploys through the Cloud Functions API, because that API owns it (see the `case` in `deploy.sh`).

## The key check
`deploy.sh` checks that the env var *name* `UNLOCK_SECRET` exists on lockapp, unlockapp and statusupdate, before and
after the deploy. It never prints values. `UNLOCK_SECRET missing on <service> after deploy` means the deploy dropped
the key and the service answers `500 server misconfiguration`: switch traffic to the previous revision (below), then fix.

## Rules
- Never use "Edit source" in the console; the next push overwrites it. Every fix is a commit.
- New behaviour is committed OFF. Flipping it is its own push, once the app build is on testers' phones.
- Server first: the server commit is on `main` and its build is green before the TestFlight build.
- Never add a pull-request trigger; this repo is public.
- Put no `.py`/`.js`/`.ts` helper under `cloudrunfunctions/`: the Desk map turns each one into a part. Don't move or
  rename the function files either.

## Rollback
Revert the commit and push; the revert deploys all five. Emergency path: Cloud Run > service > Revisions > Manage
traffic > previous revision, then push the revert. A traffic pin does not stick: every deploy ends with
`update-traffic --to-latest`, so the next server push moves the service back to the newest revision.

## Out-of-order pushes
Two server pushes a few minutes apart can finish out of order. Check that the serving revision's `commit-sha` label
matches `main`; if not, re-run the trigger on `main`.

## Bumping a dependency
The manifests are pinned as of the date each service was last built live. To bump, re-run the command with a new
date and commit the result.
- Python, inside `deploy/<svc>/`: the `uv pip compile ... --exclude-newer <date>` line recorded in the header of
  `requirements.txt` (input is `requirements.in`).
- Node, inside `deploy/<svc>/`: `npm install --package-lock-only --ignore-scripts --before=<date>`
  (keep the ranges in `package.json`; the lockfile pins).

## Where config lives
Names only:
- `UNLOCK_SECRET`: env var on lockapp, unlockapp and statusupdate; deploys never touch it.
- `ALERT_PUSH`: a constant in the function files, so changing it is a commit.
- Runtime identity: the service's own config, unchanged. Trigger identity: `ppta-deployer`, no keys.
- Function target, base image and region: `deploy/cloudbuild.yaml`.
