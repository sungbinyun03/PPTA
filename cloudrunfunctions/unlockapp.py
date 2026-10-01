from firebase_functions import https_fn
import firebase_admin
from firebase_admin import firestore, messaging
import hmac
import hashlib
import os
import time


if not firebase_admin._apps:
    firebase_admin.initialize_app()


def _bad_request(reason: str, code: int):
    return (reason, code, {"Content-Type": "text/plain"})


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

    try:
        db.collection("userSettings").document(uid).set(
            {
                "lockedByUID": firestore.DELETE_FIELD,
                "lockedByName": firestore.DELETE_FIELD,
            },
            merge=True,
        )
        print(f"Cleared lock attribution for UID: [{uid}]")
    except Exception as e:
        print(f"Error clearing lock attribution for UID [{uid}]: {e}")

    print(f"Fetching FCM token for UID: [{uid}] from 'users' collection.")
    user_doc_ref = db.collection("users").document(uid)
    snap = user_doc_ref.get()

    if not snap.exists:
        print(f"User document does not exist for UID: [{uid}] in 'users' collection")
        return _bad_request(f"user {uid} not found in 'users' collection", 404)

    token = snap.get("fcmToken")

    if not token:
        print(f"Token is None or empty for UID: [{uid}]")
        return _bad_request(f"no token for uid {uid}", 404)

    if isinstance(token, str) and not token.strip():
        print(f"Token for UID [{uid}] is a whitespace-only string")
        return _bad_request(f"invalid (whitespace) token for uid {uid}", 404)

    message = messaging.Message(
        token=token,
        data={
            "type": "unlock",
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
        print(f"Successfully sent FCM message. ID: [{message_id}]. To UID: [{uid}]")
    except Exception as e:
        print(f"Error sending FCM message for UID [{uid}]: {e}")
        return _bad_request(f"FCM send error: {str(e)}", 500)

    return ("OK", 200, {"Content-Type": "text/plain"})