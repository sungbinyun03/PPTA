from firebase_functions import https_fn
import firebase_admin
from firebase_admin import firestore, messaging
import hmac
import hashlib
import json
import os
import time
import unicodedata
import uuid

# Step 4 switch. False = the old silent background push (safe with any app build). Flip to True
# only once the build that skips its local banner when `aps.alert` is present (f6af45d) is on
# every tester's phone; older builds would show two banners.
ALERT_PUSH = False

if not firebase_admin._apps:
    firebase_admin.initialize_app()


def _command_ok(cmd_id, push=None):
    body = {"ok": True, "cmd": cmd_id}
    if push:
        body["push"] = push
    return (json.dumps(body), 200, {"Content-Type": "application/json"})


# Server cap in Unicode code points. Looser than the client's 60 Characters so a counting
# mismatch between the two can never fail an action; the server truncates, never rejects.
MAX_MESSAGE_CODE_POINTS = 100


def _clean_message(raw):
    """Mirror of ActionMessage.clean on the client: whitespace and control characters (category
    Cc) collapse to single spaces, ends are trimmed, and the result is capped. Format characters
    (e.g. U+200D ZWJ) are kept so emoji sequences survive. Returns None when nothing is left."""
    if not isinstance(raw, str):
        return None
    out = []
    last_was_space = True  # also drops leading whitespace
    for ch in raw:
        if ch.isspace() or unicodedata.category(ch) == "Cc":
            if not last_was_space:
                out.append(" ")
            last_was_space = True
        else:
            out.append(ch)
            last_was_space = False
    capped = "".join(out[:MAX_MESSAGE_CODE_POINTS]).strip(" ")  # the cut can leave a trailing space
    return capped or None


def _bad_request(reason, code):
    return (reason, code, {"Content-Type": "text/plain"})


@https_fn.on_request()
def lockApp(req: https_fn.Request) -> https_fn.Response:
    uid = req.args.get("uid")
    coach = req.args.get("coach")
    ts = req.args.get("ts")
    sig = req.args.get("sig")

    print(f"lockApp invoked. UID: [{uid}], Coach: [{coach}], TS: [{ts}], Sig provided: {sig is not None}")

    if not all([uid, coach, ts, sig]):
        return _bad_request("missing params", 400)

    secret = os.environ.get("UNLOCK_SECRET")
    if not secret:
        print("CRITICAL ERROR: UNLOCK_SECRET environment variable not found.")
        return _bad_request("server misconfiguration", 500)

    if not ts.isdigit():
        return _bad_request("invalid timestamp format", 400)

    try:
        timestamp_from_req = int(ts)
    except ValueError:
        return _bad_request("invalid timestamp format", 400)

    current_time = time.time()
    if abs(current_time - timestamp_from_req) > 5 * 60:
        print(
            f"Link expired for UID: [{uid}]. "
            f"Request ts: {timestamp_from_req}, "
            f"Current time: {int(current_time)}, "
            f"Difference: {int(current_time - timestamp_from_req)}s"
        )
        return _bad_request("link expired", 410)

    msg = f"{uid}|{coach}|{ts}".encode("utf-8")
    expected = hmac.new(secret.encode("utf-8"), msg, hashlib.sha256).hexdigest()

    if not hmac.compare_digest(expected, sig):
        print(f"Bad signature for UID: [{uid}]")
        return _bad_request("bad sig", 403)

    # Unsigned and read only after the signature check; a missing or empty note changes nothing.
    note = _clean_message(req.args.get("msg"))

    db = firestore.client()

    try:
        db.collection("lockRequests").document(uid).set(
            {
                "requestedBy": coach,
                "requestedAt": firestore.SERVER_TIMESTAMP,
            }
        )
    except Exception as e:
        print(f"Error writing audit log: {e}")

    coach_name = "Your coach"
    try:
        coach_snap = db.collection("users").document(coach).get()
        if coach_snap.exists:
            name = coach_snap.get("name")
            if isinstance(name, str) and name.strip():
                coach_name = name.strip()
    except Exception as e:
        print(f"Could not resolve coach name: {e}")

    # The command is the source of truth the trainee converges on, so a failed write must fail
    # the request (the coach sees the error) rather than push a lock that nothing records.
    cmd_id = uuid.uuid4().hex
    lock_command = {
        "id": cmd_id,
        "action": "lock",
        "by": coach,
        "byName": coach_name,
        "at": firestore.SERVER_TIMESTAMP,
    }
    if note:
        lock_command["message"] = note
    try:
        db.collection("userSettings").document(uid).set(
            {
                "lockedByUID": coach,
                "lockedByName": coach_name,
                "lockCommand": lock_command,
            },
            # Field-path merge, not merge=True: that deep-merges maps, so a stale `message` (or an
            # unlock's `lockNote`) would survive in lockCommand. Listing the path replaces the whole map.
            merge=["lockedByUID", "lockedByName", "lockCommand"],
        )
    except Exception as e:
        print(f"Error writing lockCommand to userSettings: {e}")
        return _bad_request("could not record lock command", 500)

    snap = db.collection("users").document(uid).get()
    if not snap.exists:
        return _command_ok(cmd_id, "no-token")

    # to_dict().get: snap.get() raises KeyError when the field is absent.
    token = (snap.to_dict() or {}).get("fcmToken")
    if not token or (isinstance(token, str) and not token.strip()):
        return _command_ok(cmd_id, "no-token")

    parts = coach_name.split()
    first = parts[0] if parts else "Your coach"

    if ALERT_PUSH:
        apns = messaging.APNSConfig(
            headers={
                "apns-priority": "10",
                "apns-push-type": "alert",
                "apns-collapse-id": f"lock-{uid}",
                "apns-expiration": str(int(time.time()) + 3600),
            },
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(
                        title=f"Locked by {first} 🔒",
                        body=note or "Head to a coach's profile to ask them to snooze the lock.",
                    ),
                    sound="default",
                    content_available=True,
                )
            ),
        )
    else:
        apns = messaging.APNSConfig(
            headers={
                "apns-priority": "5",
                "apns-push-type": "background",
            },
            payload=messaging.APNSPayload(
                aps=messaging.Aps(content_available=True)
            ),
        )

    push_data = {
        "type": "lock",
        "by": str(coach),
        "byName": coach_name,
        "cmd": cmd_id,
        "uid": uid,
    }
    if note:
        push_data["message"] = note

    message = messaging.Message(
        token=token,
        data=push_data,
        apns=apns,
    )

    try:
        message_id = messaging.send(message)
        print(f"Lock FCM sent. ID: [{message_id}], UID: [{uid}]")
    except Exception as e:
        print(f"FCM send error: {e}")
        # The command is already persisted and the trainee converges on it at next launch/foreground,
        # so a push failure is not a failed request; a 500 would tell the coach to retry a lock that lands.
        return _command_ok(cmd_id, "failed")

    return _command_ok(cmd_id)