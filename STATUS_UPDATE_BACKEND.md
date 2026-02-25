# Status Update Endpoint (Cloud Run) — Contract + Reference Implementation

Goal: when the DeviceActivity **monitor extension** reaches warning/threshold (and when unlock/interval end clears), it should notify a backend endpoint so coaches see trainee status **almost immediately**.

This mirrors the existing `unlockApp` function pattern (HMAC + expiry), and reuses the same `UNLOCK_SECRET`.

## Payload contract

### Request
- **Method**: `POST`
- **URL**: your deployed Cloud Run URL for `statusUpdate` (recommended as a separate function/service)
- **Content-Type**: `application/json`

Body:

```json
{
  "uid": "<trainee_uid>",
  "status": "allClear|attentionNeeded|cutOff",
  "ts": 1234567890,
  "sig": "<hex hmac>"
}
```

Signature:
- `msg = "{uid}|{status}|{ts}"`
- `sig = HMAC_SHA256(UNLOCK_SECRET, msg).hexdigest()`
- **Important**: this matches iOS’s current approach: the HMAC key is the UTF-8 bytes of the secret string (not hex-decoded).

Expiry:
- reject if `now - ts > 5 minutes` (same as unlock).

### Response
- `200 OK` with plain text body `"OK"` on success
- `4xx/5xx` plain text for errors

## Firestore writes
Update:
- `userSettings/{uid}`:
  - `traineeStatus = <status>`
  - optional: `lastStatusAt = SERVER_TIMESTAMP`

## Coach notifications (recommended)
To make it “almost immediate” even when the coach isn’t refreshing:
- Read `coachIds` from `userSettings/{uid}`
- For each coachId:
  - Read `users/{coachId}.fcmToken`
  - Send an FCM **data** message:

```json
{
  "type": "traineeStatus",
  "uid": "<trainee_uid>",
  "status": "<status>"
}
```

On iOS, `AppDelegate.didReceiveRemoteNotification` already handles `type == "traineeStatus"` and shows a local notification.

## Reference Python implementation (Firebase Admin)

This is intentionally similar to your `unlockApp` function.

```python
from firebase_functions import https_fn
import firebase_admin
from firebase_admin import firestore, messaging
import hmac, hashlib, os, time

if not firebase_admin._apps:
    firebase_admin.initialize_app()

def _bad(reason: str, code: int):
    return (reason, code, {"Content-Type": "text/plain"})

@https_fn.on_request()
def statusUpdate(req: https_fn.Request) -> https_fn.Response:
    data = req.get_json(silent=True) or {}
    uid = data.get("uid")
    status = data.get("status")
    ts = data.get("ts")
    sig = data.get("sig")

    if not all([uid, status, ts, sig]):
        return _bad("missing params", 400)

    secret = os.environ.get("UNLOCK_SECRET")
    if not secret:
        return _bad("server misconfiguration", 500)

    try:
        ts_int = int(ts)
    except Exception:
        return _bad("invalid timestamp format", 400)

    if time.time() - ts_int > 5 * 60:
        return _bad("link expired", 410)

    msg = f"{uid}|{status}|{ts_int}".encode()
    expected = hmac.new(secret.encode(), msg, hashlib.sha256).hexdigest()
    if expected != sig:
        return _bad("bad sig", 403)

    if status not in ("allClear", "attentionNeeded", "cutOff"):
        return _bad("invalid status", 400)

    db = firestore.client()

    # Update trainee status
    settings_ref = db.collection("userSettings").document(uid)
    settings_ref.set({
        "traineeStatus": status,
        "lastStatusAt": firestore.SERVER_TIMESTAMP,
    }, merge=True)

    # Fetch coachIds
    snap = settings_ref.get()
    coach_ids = (snap.get("coachIds") or []) if snap.exists else []

    # Notify coaches (best effort)
    for coach_id in coach_ids:
        coach_snap = db.collection("users").document(coach_id).get()
        token = coach_snap.get("fcmToken") if coach_snap.exists else None
        if not token:
            continue

        msg = messaging.Message(
            token=token,
            data={"type": "traineeStatus", "uid": uid, "status": status},
            apns=messaging.APNSConfig(
                headers={"apns-priority": "5", "apns-push-type": "background"},
                payload=messaging.APNSPayload(aps=messaging.Aps(content_available=True)),
            ),
        )
        try:
            messaging.send(msg)
        except Exception:
            pass

    return ("OK", 200, {"Content-Type": "text/plain"})
```

## iOS wiring points
- **Monitor extension**: `AppMonitor/DeviceActivityMonitorExtension.swift` calls `statusUpdate` on warning/reach/interval start/end.
- **Main app**: `PPTAMinimal/Managers/DeviceActivityManager.swift` calls `statusUpdate(allClear)` after remote unlock (best effort).

## TODO you must do after deploying
Update these hardcoded URLs in iOS:
- `AppMonitor/DeviceActivityMonitorExtension.swift` → `statusUpdateURL`
- `PPTAMinimal/Managers/DeviceActivityManager.swift` → `statusUpdateURL`

