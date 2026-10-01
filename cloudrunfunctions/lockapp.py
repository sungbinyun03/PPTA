from firebase_functions import https_fn
import firebase_admin
from firebase_admin import firestore, messaging
import hmac
import hashlib
import os
import time


if not firebase_admin._apps:
    firebase_admin.initialize_app()


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

    try:
        db.collection("userSettings").document(uid).set(
            {
                "lockedByUID": coach,
                "lockedByName": coach_name,
            },
            merge=True,
        )
    except Exception as e:
        print(f"Error writing lockedBy to userSettings: {e}")

    snap = db.collection("users").document(uid).get()
    if not snap.exists:
        return _bad_request(f"user {uid} not found", 404)

    token = snap.get("fcmToken")
    if not token or (isinstance(token, str) and not token.strip()):
        return _bad_request(f"no token for uid {uid}", 404)

    message = messaging.Message(
        token=token,
        data={
            "type": "lock",
            "by": str(coach),
            "byName": coach_name,
        },
        apns=messaging.APNSConfig(
            headers={
                "apns-priority": "5",
                "apns-push-type": "background",
            },
            payload=messaging.APNSPayload(
                aps=messaging.Aps(content_available=True)
            ),
        ),
    )

    try:
        message_id = messaging.send(message)
        print(f"Lock FCM sent. ID: [{message_id}], UID: [{uid}]")
    except Exception as e:
        print(f"FCM send error: {e}")
        return _bad_request(f"FCM send error: {str(e)}", 500)

    return ("OK", 200, {"Content-Type": "text/plain"})