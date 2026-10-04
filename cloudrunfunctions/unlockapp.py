from firebase_functions import https_fn
import firebase_admin
from firebase_admin import firestore, messaging
import hmac
import hashlib
import json
import os
import time
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


def _bad_request(reason: str, code: int):
    return (reason, code, {"Content-Type": "text/plain"})


def _lock_note_for(prev):
    """The lock note to carry through a snooze: the previous lock's note, or one an earlier snooze
    in the same lock episode already carried. None when there isn't one."""
    if not isinstance(prev, dict):
        return None
    if prev.get("action") == "lock":
        message = prev.get("message")
        if isinstance(message, str) and message.strip():
            return {
                "message": message,
                "by": prev.get("by"),
                "byName": prev.get("byName"),
                "lockId": prev.get("id"),
            }
        return None
    if prev.get("action") == "unlock" and isinstance(prev.get("lockNote"), dict):
        return prev["lockNote"]
    return None


def _record_unlock(transaction, ref, cmd_id, coach, coach_name):
    """Writes the unlock command in one transaction so a lock landing mid-write can't be overwritten
    by an unlock carrying an older note. `update` with a map value replaces the whole lockCommand
    (set(merge=True) deep-merges maps, which would leave the lock's `message` behind)."""
    snap = ref.get(transaction=transaction)
    command = {
        "id": cmd_id,
        "action": "unlock",
        "by": coach,
        "byName": coach_name,
        "at": firestore.SERVER_TIMESTAMP,
    }
    if not snap.exists:
        transaction.set(ref, {"lockCommand": command})
        return
    lock_note = _lock_note_for((snap.to_dict() or {}).get("lockCommand"))
    if lock_note:
        command["lockNote"] = lock_note
    transaction.update(ref, {
        "lockedByUID": firestore.DELETE_FIELD,
        "lockedByName": firestore.DELETE_FIELD,
        "lockCommand": command,
    })


@https_fn.on_request()
def unlockApp(req: https_fn.Request) -> https_fn.Response:
    uid = req.args.get("uid")
    coach = req.args.get("coach")
    ts = req.args.get("ts")
    sig = req.args.get("sig")

    print(f"Function invoked. UID: [{uid}], Coach: [{coach}], TS: [{ts}], Sig provided: {sig is not None}")

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

    db = firestore.client()
    print(f"Firestore client obtained successfully for UID: [{uid}]")

    try:
        db.collection("unlockRequests").document(uid).set({
            "requestedBy": coach,
            "requestedAt": firestore.SERVER_TIMESTAMP,
        })
        print(f"Audit log created for UID: [{uid}] by coach: [{coach}]")
    except Exception as e:
        print(f"Error writing audit log for UID [{uid}]: {e}")

    coach_name = "Your coach"
    try:
        coach_snap = db.collection("users").document(coach).get()
        if coach_snap.exists:
            name = coach_snap.get("name")
            if isinstance(name, str) and name.strip():
                coach_name = name.strip()
    except Exception as e:
        print(f"Could not resolve coach name for coach [{coach}]: {e}")

    # The command is the source of truth the trainee converges on, so a failed write must fail
    # the request (the coach sees the error) rather than push an unlock that nothing records.
    cmd_id = uuid.uuid4().hex
    try:
        ref = db.collection("userSettings").document(uid)
        firestore.transactional(_record_unlock)(db.transaction(), ref, cmd_id, coach, coach_name)
        print(f"Recorded unlock command [{cmd_id}] for UID: [{uid}]")
    except Exception as e:
        print(f"Error writing lockCommand for UID [{uid}]: {e}")
        return _bad_request("could not record unlock command", 500)

    print(f"Fetching FCM token for UID: [{uid}] from 'users' collection.")
    user_doc_ref = db.collection("users").document(uid)
    snap = user_doc_ref.get()

    if not snap.exists:
        print(f"User document does not exist for UID: [{uid}] in 'users' collection")
        return _command_ok(cmd_id, "no-token")

    # to_dict().get: snap.get() raises KeyError when the field is absent.
    token = (snap.to_dict() or {}).get("fcmToken")

    if not token:
        print(f"Token is None or empty for UID: [{uid}]")
        return _command_ok(cmd_id, "no-token")

    if isinstance(token, str) and not token.strip():
        print(f"Token for UID [{uid}] is a whitespace-only string")
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
                        title=f"Lock snoozed by {first}! ⏳",
                        body="You've got 10 minutes before your apps lock again — make them count!",
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

    message = messaging.Message(
        token=token,
        data={
            "type": "unlock",
            "by": str(coach),
            "byName": coach_name,
            "cmd": cmd_id,
            "uid": uid,
        },
        apns=apns,
    )

    try:
        message_id = messaging.send(message)
        print(f"Successfully sent FCM message. ID: [{message_id}]. To UID: [{uid}]")
    except Exception as e:
        print(f"Error sending FCM message for UID [{uid}]: {e}")
        # Command already persisted; see lockApp for why a push failure is a 200.
        return _command_ok(cmd_id, "failed")

    return _command_ok(cmd_id)