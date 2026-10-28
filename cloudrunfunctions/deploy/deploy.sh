#!/usr/bin/env bash
# Stages one function's source next to its pinned manifest and deploys it from the committed files.
# Only the source changes: every other setting of the live service (env, identity, access, scaling) is left alone.
# Usage: deploy.sh <service> <source-file> <function-target> <base-image-or-runtime> <short-sha>
set -euo pipefail

if [ "$#" -ne 5 ]; then
  echo "usage: $0 <service> <source-file> <function-target> <base-image-or-runtime> <short-sha>" >&2
  exit 2
fi
SERVICE=$1 SOURCE_FILE=$2 TARGET=$3 BASE=$4 SHA=$5
REGION=us-central1
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)   # cloudrunfunctions/

# Hazard 1 (plan.md): the deploy may pass only source, function, base image, region, --update-labels and --quiet.
# Never add any env-var, secret, service-account, auth (--[no-]allow-unauthenticated), --labels, --ingress,
# build-env, scaling, memory or timeout flag. Any of them rewrites the live service: UNLOCK_SECRET is dropped,
# every app call turns into a 403, or the runtime identity changes.

# Mode per service (11-drift-ruling section 1): unlockapp is owned by the Cloud Functions API (function id
# unlockApp, case-sensitive), so it deploys through that API; the others are plain Cloud Run services.
case "$SERVICE" in
  unlockapp)     MODE=functions; NEED_KEY=1 ;;
  lockapp)       MODE=run;       NEED_KEY=1 ;;
  statusupdate)  MODE=run;       NEED_KEY=1 ;;
  role-requests) MODE=run;       NEED_KEY=0 ;;
  deleteaccount) MODE=run;       NEED_KEY=0 ;;
  *) echo "unknown service: $SERVICE" >&2; exit 2 ;;
esac

# Reads describe JSON on stdin and prints only whether the env var NAME exists; the JSON holds the value.
KEYCHECK_PY='
import json, sys
try:
    d = json.load(sys.stdin)
    if sys.argv[1] == "functions":
        names = list(d["serviceConfig"]["environmentVariables"])
    else:
        names = [e["name"] for e in d["spec"]["template"]["spec"]["containers"][0]["env"]]
except Exception:
    names = []
print("UNLOCK_SECRET present" if "UNLOCK_SECRET" in names else "UNLOCK_SECRET MISSING")
'

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp "$DIR/deploy/$SERVICE"/* "$STAGE"/
case "$SOURCE_FILE" in
  *.py) cp "$DIR/$SOURCE_FILE" "$STAGE/main.py" ;;
  *.js) cp "$DIR/$SOURCE_FILE" "$STAGE/index.js" ;;
  *) echo "unsupported source file: $SOURCE_FILE" >&2; exit 2 ;;
esac

DESCRIBE_RUN=(gcloud run services describe "$SERVICE" --region "$REGION" --format=json)
DESCRIBE_FN=(gcloud functions describe unlockApp --region "$REGION" --format=json)

if [ "$MODE" = functions ]; then
  DEPLOY=(gcloud functions deploy unlockApp --gen2 --region "$REGION" --runtime "$BASE" --source "$STAGE"
          --entry-point unlockApp --trigger-http --update-labels "commit-sha=$SHA" --quiet)
  PRE=("${DESCRIBE_FN[@]}")
else
  DEPLOY=(gcloud run deploy "$SERVICE" --source "$STAGE" --function "$TARGET" --base-image "$BASE"
          --region "$REGION" --update-labels "commit-sha=$SHA" --quiet)
  TRAFFIC=(gcloud run services update-traffic "$SERVICE" --to-latest --region "$REGION" --quiet)
  PRE=("${DESCRIBE_RUN[@]}")
fi

if [ "${DRY_RUN:-}" = 1 ]; then
  echo "staged files in <tmp>:"; (cd "$STAGE" && ls -1 | sed 's/^/  /')
  if [ "$NEED_KEY" = 1 ]; then echo "pre-check:  ${PRE[*]} | python3 -c <keycheck $MODE>"; fi
  echo "deploy:     ${DEPLOY[*]}"
  if [ "$MODE" = run ]; then echo "traffic:    ${TRAFFIC[*]}"; fi
  if [ "$NEED_KEY" = 1 ]; then echo "post-check: ${DESCRIBE_RUN[*]} | python3 -c <keycheck run>"; fi
  exit 0
fi

check_key() {  # $1 = functions|run, then the describe command; output is the name check only
  local shape=$1; shift
  "$@" | python3 -c "$KEYCHECK_PY" "$shape" || echo "UNLOCK_SECRET MISSING"
}

if [ "$NEED_KEY" = 1 ]; then
  RESULT=$(check_key "$MODE" "${PRE[@]}" 2>/dev/null | tail -n 1)
  echo "pre-check $SERVICE: $RESULT"
  if [ "$RESULT" != "UNLOCK_SECRET present" ]; then
    echo "refusing to deploy $SERVICE: UNLOCK_SECRET is not in the config this deploy would rebuild from" >&2
    exit 1
  fi
fi

"${DEPLOY[@]}"
if [ "$MODE" = run ]; then "${TRAFFIC[@]}"; fi

if [ "$NEED_KEY" = 1 ]; then
  RESULT=$(check_key run "${DESCRIBE_RUN[@]}" 2>/dev/null | tail -n 1)
  echo "post-check $SERVICE: $RESULT"
  if [ "$RESULT" != "UNLOCK_SECRET present" ]; then
    echo "UNLOCK_SECRET missing on $SERVICE after deploy: Cloud Run > $SERVICE > Revisions > Manage traffic > previous revision" >&2
    exit 1
  fi
fi
