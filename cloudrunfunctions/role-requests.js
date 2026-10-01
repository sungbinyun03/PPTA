'use strict';

const functions = require("@google-cloud/functions-framework");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function json(res, status, obj) {
  res.status(status).set("Content-Type", "application/json").send(JSON.stringify(obj));
}

async function requireUid(req, res) {
  const header = req.get("Authorization") || "";
  const m = header.match(/^Bearer\s+(.+)$/);

  if (!m) {
    json(res, 401, { error: "Missing Authorization: Bearer <idToken>" });
    return null;
  }

  try {
    const decoded = await admin.auth().verifyIdToken(m[1]);
    return decoded.uid;
  } catch (e) {
    json(res, 401, { error: "Invalid Firebase ID token" });
    return null;
  }
}

async function areFriends(a, b) {
  const q1 = await db.collection("friendships")
    .where("requesterId", "==", a)
    .where("requesteeId", "==", b)
    .where("status", "==", "accepted")
    .limit(1)
    .get();

  if (!q1.empty) return true;

  const q2 = await db.collection("friendships")
    .where("requesterId", "==", b)
    .where("requesteeId", "==", a)
    .where("status", "==", "accepted")
    .limit(1)
    .get();

  return !q2.empty;
}

function requireRole(role, res) {
  if (role === "coach" || role === "trainee") return role;

  json(res, 400, { error: "Invalid role. Must be 'coach' or 'trainee'." });
  return null;
}

function requestId(requesterId, targetId, role) {
  return `${requesterId}_${targetId}_${role}`;
}

function settingsRef(uid) {
  return db.collection("userSettings").doc(uid);
}

/// A relationship "X coaches Y" can have been created by either of two request docs:
///   { requesterId: X, targetId: Y, role: "coach"   }  -> X coaches Y
///   { requesterId: Y, targetId: X, role: "trainee" }  -> Y is trainee of X
/// Both must be cleared when the relationship ends, otherwise createRoleRequest
/// later rejects the same pair with ALREADY_ACCEPTED forever.
function roleRequestIdsForCoaching(coachUid, traineeUid) {
  return [
    requestId(coachUid, traineeUid, "coach"),
    requestId(traineeUid, coachUid, "trainee"),
  ];
}

/// Every request doc that could exist between two users, in either direction.
function roleRequestIdsBetween(a, b) {
  return [
    ...roleRequestIdsForCoaching(a, b),
    ...roleRequestIdsForCoaching(b, a),
  ];
}

const LOCKED_STATUSES = new Set(["cutOff", "snoozedLock"]);

/// Blocks removing one of your own coaches while you are shielded.
///
/// The shield lives in ManagedSettings on the trainee's device and survives the
/// relationship being deleted, so dropping your last coach while cut off does not
/// unlock you — it just deletes the only person who can release you, leaving you
/// locked until `intervalDidEnd` clears it at midnight.
async function assertNotRemovingCoachWhileLocked(uid, otherId) {
  const snap = await settingsRef(uid).get();
  if (!snap.exists) return;

  // `isTracking` false means pressure level Off, where a leftover cutOff status is stale.
  if (snap.get("isTracking") === false) return;
  if (!LOCKED_STATUSES.has(snap.get("traineeStatus"))) return;

  const coachIds = snap.get("coachIds") || [];
  if (coachIds.includes(otherId)) throw new Error("LOCKED_BY_COACH");
}

async function getUserName(uid) {
  try {
    const snap = await db.collection("users").doc(uid).get();
    return snap.exists ? (snap.get("name") || null) : null;
  } catch (e) {
    return null;
  }
}

async function getFcmToken(uid) {
  try {
    const snap = await db.collection("users").doc(uid).get();
    const token = snap.exists ? snap.get("fcmToken") : null;
    return typeof token === "string" && token.trim() ? token : null;
  } catch (e) {
    return null;
  }
}

async function sendDataPush(token, data) {
  if (!token) return;

  try {
    await admin.messaging().send({
      token,
      data,
      apns: {
        headers: {
          "apns-priority": "5",
          "apns-push-type": "background",
        },
        payload: {
          aps: { "content-available": 1 },
        },
      },
    });
  } catch (e) {
    console.error("FCM send error:", e);
  }
}

/// Silent nudge so the other device drops coachIds/traineeIds entries that this
/// request just deleted. Deliberately produces no user-visible alert.
async function sendRelationshipsChanged(uid) {
  await sendDataPush(await getFcmToken(uid), { type: "relationshipsChanged" });
}

/// True when the requester's relationship arrays actually back an "accepted" request
/// doc. Used to detect a stale `accepted` doc whose relationship was already removed
/// (or was never mirrored into the arrays), so createRoleRequest can self-heal instead
/// of rejecting the pair forever with ALREADY_ACCEPTED.
///   role "coach"   -> uid coaches target -> target must be in uid.traineeIds
///   role "trainee" -> uid is trainee of target -> target must be in uid.coachIds
function acceptedRelationshipHolds(mySettingsSnap, targetId, role) {
  const traineeIds = (mySettingsSnap.exists && mySettingsSnap.get("traineeIds")) || [];
  const coachIds = (mySettingsSnap.exists && mySettingsSnap.get("coachIds")) || [];
  return role === "coach"
    ? traineeIds.includes(targetId)
    : coachIds.includes(targetId);
}

functions.http("roleRequests", async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "POST") return json(res, 405, { error: "POST only" });

  const uid = await requireUid(req, res);
  if (!uid) return;

  const action = req.body && req.body.action;
  if (!action) return json(res, 400, { error: "Missing action" });

  try {
    if (action === "createRoleRequest") {
      const targetId = String(req.body.targetId || "");
      const role = requireRole(req.body.role, res);
      if (!role) return;

      if (!targetId) return json(res, 400, { error: "targetId is required" });
      if (targetId === uid) return json(res, 400, { error: "Cannot request yourself" });

      if (!(await areFriends(uid, targetId))) {
        return json(res, 412, { error: "Role requests require an accepted friendship" });
      }

      const id = requestId(uid, targetId, role);
      const ref = db.collection("roleRequests").doc(id);

      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);

        if (snap.exists) {
          const status = snap.get("status");
          if (status === "pending") throw new Error("ALREADY_PENDING");
          if (status === "accepted") {
            // Self-heal: only reject if the relationship arrays actually back this
            // "accepted" doc. A leftover doc whose relationship was already removed
            // (legacy data, account-deletion paths, or any array/ledger drift) would
            // otherwise block this pair+role forever. Reads stay before the write below,
            // as Firestore transactions require.
            const mySnap = await tx.get(settingsRef(uid));
            if (acceptedRelationshipHolds(mySnap, targetId, role)) {
              throw new Error("ALREADY_ACCEPTED");
            }
            // else: stale doc — fall through and overwrite it with a fresh pending request.
          }
          // "declined" / "cancelled" also fall through to overwrite (unchanged behavior).
        }

        tx.set(ref, {
          requesterId: uid,
          targetId,
          role,
          status: "pending",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          resolvedAt: null,
        }, { merge: false });
      });

      const requesterName = await getUserName(uid);
      const targetToken = await getFcmToken(targetId);

      await sendDataPush(targetToken, {
        type: "roleRequestReceived",
        requesterId: uid,
        requesterName: requesterName || "Someone",
        role,
      });

      return json(res, 200, { id });
    }

    if (action === "acceptRoleRequest") {
      const id = String(req.body.id || "");
      if (!id) return json(res, 400, { error: "id is required" });

      const ref = db.collection("roleRequests").doc(id);
      let requesterId = null;
      let role = null;

      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) throw new Error("NOT_FOUND");

        requesterId = snap.get("requesterId");
        const targetId = snap.get("targetId");
        role = snap.get("role");
        const status = snap.get("status");

        if (targetId !== uid) throw new Error("FORBIDDEN");
        if (status !== "pending") throw new Error("NOT_PENDING");
        if (!(await areFriends(requesterId, targetId))) throw new Error("NOT_FRIENDS");

        const requesterSettings = settingsRef(requesterId);
        const targetSettings = settingsRef(targetId);

        if (role === "coach") {
          tx.set(targetSettings, {
            coachIds: admin.firestore.FieldValue.arrayUnion(requesterId),
          }, { merge: true });

          tx.set(requesterSettings, {
            traineeIds: admin.firestore.FieldValue.arrayUnion(targetId),
          }, { merge: true });
        } else if (role === "trainee") {
          tx.set(targetSettings, {
            traineeIds: admin.firestore.FieldValue.arrayUnion(requesterId),
          }, { merge: true });

          tx.set(requesterSettings, {
            coachIds: admin.firestore.FieldValue.arrayUnion(targetId),
          }, { merge: true });
        } else {
          throw new Error("BAD_ROLE");
        }

        tx.update(ref, {
          status: "accepted",
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      const acceptorName = await getUserName(uid);
      const requesterToken = await getFcmToken(requesterId);

      await sendDataPush(requesterToken, {
        type: "roleRequestAccepted",
        acceptorId: uid,
        acceptorName: acceptorName || "Your friend",
        role,
      });

      return json(res, 200, { ok: true });
    }

    if (action === "declineRoleRequest") {
      const id = String(req.body.id || "");
      if (!id) return json(res, 400, { error: "id is required" });

      const ref = db.collection("roleRequests").doc(id);

      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) throw new Error("NOT_FOUND");

        if (snap.get("targetId") !== uid) throw new Error("FORBIDDEN");
        if (snap.get("status") !== "pending") throw new Error("NOT_PENDING");

        tx.update(ref, {
          status: "declined",
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      return json(res, 200, { ok: true });
    }

    if (action === "cancelRoleRequest") {
      const id = String(req.body.id || "");
      if (!id) return json(res, 400, { error: "id is required" });

      const ref = db.collection("roleRequests").doc(id);

      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) throw new Error("NOT_FOUND");

        if (snap.get("requesterId") !== uid) throw new Error("FORBIDDEN");
        if (snap.get("status") !== "pending") throw new Error("NOT_PENDING");

        tx.update(ref, {
          status: "cancelled",
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      return json(res, 200, { ok: true });
    }

    if (action === "removeRoleRelationship") {
      const otherId = String(req.body.otherId || "");
      const role = requireRole(req.body.role, res);
      if (!role) return;

      if (!otherId) return json(res, 400, { error: "otherId is required" });
      if (otherId === uid) return json(res, 400, { error: "Cannot remove yourself" });

      if (!(await areFriends(uid, otherId))) {
        return json(res, 412, { error: "Must be friends to remove relationship" });
      }

      // role "trainee" means otherId coaches uid — i.e. uid is dropping one of their coaches.
      if (role === "trainee") {
        await assertNotRemovingCoachWhileLocked(uid, otherId);
      }

      // Which request docs produced this relationship.
      const staleRequestIds = role === "coach"
        ? roleRequestIdsForCoaching(uid, otherId)
        : roleRequestIdsForCoaching(otherId, uid);

      const batch = db.batch();
      const a = settingsRef(uid);
      const b = settingsRef(otherId);

      if (role === "coach") {
        batch.set(a, {
          traineeIds: admin.firestore.FieldValue.arrayRemove(otherId),
        }, { merge: true });

        batch.set(b, {
          coachIds: admin.firestore.FieldValue.arrayRemove(uid),
        }, { merge: true });
      } else {
        batch.set(a, {
          coachIds: admin.firestore.FieldValue.arrayRemove(otherId),
        }, { merge: true });

        batch.set(b, {
          traineeIds: admin.firestore.FieldValue.arrayRemove(uid),
        }, { merge: true });
      }

      // Without this the pair can never re-request the same role: createRoleRequest
      // sees the leftover "accepted" doc and returns ALREADY_ACCEPTED.
      for (const id of staleRequestIds) {
        batch.delete(db.collection("roleRequests").doc(id));
      }

      await batch.commit();
      await sendRelationshipsChanged(otherId);

      return json(res, 200, { ok: true });
    }

    if (action === "unfriend") {
      const otherId = String(req.body.otherId || "");
      if (!otherId) return json(res, 400, { error: "otherId is required" });
      if (otherId === uid) return json(res, 400, { error: "Cannot unfriend yourself" });

      await assertNotRemovingCoachWhileLocked(uid, otherId);

      // Every friendship doc between the pair, in both directions and at any status.
      // sendFriendRequest does not dedupe, so A->B and B->A can both exist, and a
      // stale pending doc left behind would let the pair re-appear as "Pending".
      const [outgoing, incoming] = await Promise.all([
        db.collection("friendships")
          .where("requesterId", "==", uid)
          .where("requesteeId", "==", otherId)
          .get(),
        db.collection("friendships")
          .where("requesterId", "==", otherId)
          .where("requesteeId", "==", uid)
          .get(),
      ]);

      const batch = db.batch();

      for (const doc of outgoing.docs) batch.delete(doc.ref);
      for (const doc of incoming.docs) batch.delete(doc.ref);

      for (const id of roleRequestIdsBetween(uid, otherId)) {
        batch.delete(db.collection("roleRequests").doc(id));
      }

      // Unconditional removal in both directions: idempotent, and it self-heals
      // pairs whose arrays already drifted out of sync.
      batch.set(settingsRef(uid), {
        coachIds: admin.firestore.FieldValue.arrayRemove(otherId),
        traineeIds: admin.firestore.FieldValue.arrayRemove(otherId),
      }, { merge: true });

      batch.set(settingsRef(otherId), {
        coachIds: admin.firestore.FieldValue.arrayRemove(uid),
        traineeIds: admin.firestore.FieldValue.arrayRemove(uid),
      }, { merge: true });

      await batch.commit();
      await sendRelationshipsChanged(otherId);

      // Deliberately succeeds even when nothing was found: unfriend has to work on
      // half-broken data, and the client treats 200 as "you are not friends anymore".
      return json(res, 200, {
        ok: true,
        removedFriendships: outgoing.size + incoming.size,
      });
    }

    return json(res, 400, { error: `Unknown action: ${action}` });
  } catch (e) {
    const msg = String(e && e.message ? e.message : "");

    if (msg === "ALREADY_PENDING") return json(res, 409, { error: "Request already pending" });
    if (msg === "ALREADY_ACCEPTED") return json(res, 409, { error: "Request already accepted" });
    if (msg === "NOT_FOUND") return json(res, 404, { error: "Not found" });
    if (msg === "FORBIDDEN") return json(res, 403, { error: "Forbidden" });
    if (msg === "NOT_PENDING") return json(res, 412, { error: "Not pending" });
    if (msg === "NOT_FRIENDS") return json(res, 412, { error: "Not friends" });
    if (msg === "LOCKED_BY_COACH") {
      return json(res, 412, { error: "You can't remove a coach while your apps are locked." });
    }

    console.error("roleRequests unhandled error:", e);
    return json(res, 500, { error: "Internal error" });
  }
});