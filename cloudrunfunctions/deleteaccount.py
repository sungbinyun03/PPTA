from firebase_functions import https_fn
import firebase_admin
from firebase_admin import firestore, auth, storage
from google.cloud.firestore_v1.base_query import FieldFilter


if not firebase_admin._apps:
    firebase_admin.initialize_app()


def _bad_request(reason, code):
    return (reason, code, {"Content-Type": "text/plain"})


@https_fn.on_request()
def deleteAccount(req: https_fn.Request) -> https_fn.Response:
    # --- Authenticate the caller via their Firebase ID token (same model as roleRequests) ---
    auth_header = req.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return _bad_request("missing auth token", 401)

    id_token = auth_header.split("Bearer ", 1)[1].strip()
    try:
        decoded = auth.verify_id_token(id_token)
    except Exception as e:
        print(f"deleteAccount: token verification failed: {e}")
        return _bad_request("invalid auth token", 401)

    uid = decoded["uid"]
    print(f"deleteAccount invoked for uid: [{uid}]")

    db = firestore.client()

    # --- 1. Scrub this uid from EVERY other user's coachIds / traineeIds ---
    try:
        for other in db.collection("userSettings").where(
            filter=FieldFilter("coachIds", "array_contains", uid)
        ).stream():
            other.reference.update({"coachIds": firestore.ArrayRemove([uid])})
        for other in db.collection("userSettings").where(
            filter=FieldFilter("traineeIds", "array_contains", uid)
        ).stream():
            other.reference.update({"traineeIds": firestore.ArrayRemove([uid])})
    except Exception as e:
        print(f"deleteAccount: relationship scrub error: {e}")

    # --- 2. Delete friendships & roleRequests involving this uid (either side) ---
    try:
        for coll, fields in [("friendships", ["requesterId", "requesteeId"]),
                             ("roleRequests", ["requesterId", "targetId"])]:
            for field in fields:
                for doc in db.collection(coll).where(
                    filter=FieldFilter(field, "==", uid)
                ).stream():
                    doc.reference.delete()
    except Exception as e:
        print(f"deleteAccount: request cleanup error: {e}")

    # --- 3. Delete audit / lock state ---
    try:
        db.collection("lockRequests").document(uid).delete()
    except Exception as e:
        print(f"deleteAccount: lockRequests delete error: {e}")

    # --- 4. Delete this user's own documents ---
    try:
        db.collection("userSettings").document(uid).delete()
        db.collection("users").document(uid).delete()
    except Exception as e:
        print(f"deleteAccount: own-doc delete error: {e}")

    # --- 5. Delete the profile image blob (best-effort) ---
    try:
        bucket = storage.bucket("ppta-3a347.firebasestorage.app")
        blob = bucket.blob(f"profilePictures/{uid}.jpg")
        if blob.exists():
            blob.delete()
    except Exception as e:
        print(f"deleteAccount: profile image delete error: {e}")

    # --- 6. Delete the Firebase Auth record LAST (admin — no recent-login required) ---
    try:
        auth.delete_user(uid)
    except auth.UserNotFoundError:
        pass  # already gone — treat as success
    except Exception as e:
        print(f"deleteAccount: auth.delete_user failed: {e}")
        return _bad_request(f"auth delete failed: {e}", 500)

    print(f"deleteAccount: completed for uid [{uid}]")
    return ("OK", 200, {"Content-Type": "text/plain"})
