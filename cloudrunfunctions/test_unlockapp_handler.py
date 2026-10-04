"""Handler-level tests for unlockApp with Firestore and FCM stubbed (no network, no real services).

The transaction is faked: it runs the function against a snapshot of the doc and, when asked, runs it a
second time to simulate Firestore retrying after a concurrent write."""
import hashlib
import hmac
import os
import subprocess
import sys
import types
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

for _n in ("firebase_functions", "firebase_admin"):
    sys.modules.setdefault(_n, mock.MagicMock())
sys.modules["firebase_functions"].https_fn.on_request = lambda *a, **k: (lambda f: f)
sys.modules["firebase_admin"]._apps = [1]

import unlockapp  # noqa: E402

SECRET = "test-secret"
NOW = 1_800_000_000
UID, COACH = "trainee1", "coach1"
CMD = "c" * 32
DELETE = "<DELETE>"
TS = "<SERVER_TS>"


class FakeSnap:
    def __init__(self, data):
        self._d = data

    @property
    def exists(self):
        return self._d is not None

    def get(self, k):
        return self._d[k]

    def to_dict(self):
        return self._d


class FakeTxn:
    def __init__(self):
        self.ops = []  # ("set"|"update", data)

    def set(self, ref, data, **kw):
        self.ops.append(("set", data, kw))

    def update(self, ref, data):
        self.ops.append(("update", data))


class FakeDB:
    def __init__(self, settings, fail_txn=False, retries=0):
        self.users = {COACH: {"name": "Coach Carter"}, UID: {"fcmToken": "tok"}}
        self.settings = settings
        self.fail_txn = fail_txn
        self.retries = retries
        self.txns = []
        self.plain_sets = []  # non-transactional writes to userSettings

    def transaction(self):
        t = FakeTxn()
        self.txns.append(t)
        return t

    def collection(self, name):
        db = self

        class Col:
            def document(self, doc):
                class Doc:
                    def set(_s, data, **kw):
                        if name == "userSettings":
                            db.plain_sets.append((data, kw))

                    def get(_s, transaction=None):
                        src = db.users.get(doc) if name == "users" else db.settings
                        return FakeSnap(src)

                return Doc()

        return Col()


class FakeMessaging:
    def __init__(self):
        self.sent = []

    def APNSConfig(self, **kw):
        return ("APNSConfig", kw)

    def APNSPayload(self, **kw):
        return ("APNSPayload", kw)

    def Aps(self, **kw):
        return ("Aps", kw)

    def ApsAlert(self, **kw):
        return ("ApsAlert", kw)

    def Message(self, **kw):
        return ("Message", kw)

    def send(self, m):
        self.sent.append(m)
        return "mid"


class FakeFirestoreMod:
    SERVER_TIMESTAMP = TS
    DELETE_FIELD = DELETE

    def __init__(self, db):
        self._db = db

    def client(self):
        return self._db

    def transactional(self, fn):
        db = self._db

        def run(transaction, *args):
            if db.fail_txn:
                raise RuntimeError("txn failed")
            for _ in range(db.retries):
                fn(FakeTxn(), *args)  # a discarded attempt, as on a Firestore retry
            return fn(transaction, *args)

        return run


def sign(uid=UID, coach=COACH, ts=NOW):
    return hmac.new(SECRET.encode(), f"{uid}|{coach}|{ts}".encode(), hashlib.sha256).hexdigest()


class Req:
    def __init__(self, args):
        self.args = args


def call(settings, mod=unlockapp, **dbkw):
    db = FakeDB(settings, **dbkw)
    fm = FakeMessaging()
    args = {"uid": UID, "coach": COACH, "ts": str(NOW), "sig": sign()}
    with mock.patch.object(mod, "firestore", FakeFirestoreMod(db)), \
            mock.patch.object(mod, "messaging", fm), \
            mock.patch.object(mod, "ALERT_PUSH", False), \
            mock.patch.object(mod.time, "time", lambda: NOW), \
            mock.patch.object(mod.uuid, "uuid4", lambda: types.SimpleNamespace(hex=CMD)), \
            mock.patch.dict(os.environ, {"UNLOCK_SECRET": SECRET}):
        resp = mod.unlockApp(Req(args))
    return resp, db, fm


def written_command(db):
    (op, *rest), = db.txns[-1].ops
    data = rest[0]
    return op, data, data["lockCommand"]


LOCK_WITH_NOTE = {"id": "L1", "action": "lock", "by": "coachA", "byName": "Alex Q", "message": "exam at 4"}
NOTE = {"message": "exam at 4", "by": "coachA", "byName": "Alex Q", "lockId": "L1"}


class LockNote(unittest.TestCase):
    def test_previous_lock_with_note_is_copied(self):
        resp, db, _ = call({"lockCommand": LOCK_WITH_NOTE})
        self.assertEqual(resp[1], 200)
        _, _, cmd = written_command(db)
        self.assertEqual(cmd["lockNote"], NOTE)
        self.assertEqual(cmd["lockNote"]["lockId"], "L1")

    def test_previous_lock_without_note_has_none(self):
        _, db, _ = call({"lockCommand": {"id": "L1", "action": "lock", "by": "coachA"}})
        self.assertNotIn("lockNote", written_command(db)[2])

    def test_previous_unlock_with_note_is_carried(self):
        _, db, _ = call({"lockCommand": {"id": "U1", "action": "unlock", "lockNote": NOTE}})
        self.assertEqual(written_command(db)[2]["lockNote"], NOTE)

    def test_previous_unlock_without_note_has_none(self):
        _, db, _ = call({"lockCommand": {"id": "U1", "action": "unlock"}})
        self.assertNotIn("lockNote", written_command(db)[2])

    def test_no_previous_command_has_none(self):
        _, db, _ = call({"lockedByUID": "x"})
        self.assertNotIn("lockNote", written_command(db)[2])

    def test_retry_reads_fresh_and_writes_once(self):
        _, db, _ = call({"lockCommand": LOCK_WITH_NOTE}, retries=1)
        self.assertEqual(len(db.txns[-1].ops), 1)
        self.assertEqual(written_command(db)[2]["lockNote"], NOTE)


class WriteShape(unittest.TestCase):
    def test_full_replace_without_message(self):
        _, db, _ = call({"lockCommand": LOCK_WITH_NOTE})
        op, data, cmd = written_command(db)
        self.assertEqual(op, "update")
        self.assertNotIn("message", cmd)
        self.assertEqual(
            cmd, {"id": CMD, "action": "unlock", "by": COACH, "byName": "Coach Carter", "at": TS, "lockNote": NOTE}
        )
        self.assertEqual(db.plain_sets, [])

    def test_locker_fields_deleted(self):
        _, db, _ = call({"lockCommand": LOCK_WITH_NOTE, "lockedByUID": "coachA"})
        _, data, _ = written_command(db)
        self.assertEqual(data["lockedByUID"], DELETE)
        self.assertEqual(data["lockedByName"], DELETE)

    def test_missing_doc_sets_without_deletes(self):
        _, db, _ = call(None)
        op, data, cmd = written_command(db)
        self.assertEqual(op, "set")
        self.assertEqual(list(data), ["lockCommand"])
        self.assertNotIn("lockNote", cmd)


class Failure(unittest.TestCase):
    def test_transaction_error_is_500_and_no_push(self):
        resp, db, fm = call({"lockCommand": LOCK_WITH_NOTE}, fail_txn=True)
        self.assertEqual(resp[:2], ("could not record unlock command", 500))
        self.assertEqual(fm.sent, [])


class Push(unittest.TestCase):
    def test_push_payload_identical_to_head(self):
        src = subprocess.check_output(
            ["git", "show", "HEAD:cloudrunfunctions/unlockapp.py"], cwd=REPO
        ).decode()
        head = types.ModuleType("unlockapp_head")
        exec(compile(src, "unlockapp_head.py", "exec"), head.__dict__)
        if "_record_unlock" in head.__dict__:
            self.skipTest("HEAD already has the transaction; comparison would be against itself")

        # HEAD writes with set(merge=True) on the document, which the fake accepts.
        resp_old, _, fm_old = call({}, mod=head)
        resp_new, _, fm_new = call({"lockCommand": LOCK_WITH_NOTE})
        self.assertEqual(resp_new, resp_old)
        self.assertEqual(fm_new.sent, fm_old.sent)
        self.assertEqual(
            set(fm_new.sent[0][1]["data"]), {"type", "by", "byName", "cmd", "uid"}
        )


if __name__ == "__main__":
    unittest.main()
