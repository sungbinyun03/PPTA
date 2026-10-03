"""Handler-level tests for lockApp with Firestore and FCM fully stubbed (no network, no real services).

The "before" baseline for the no-msg case is the committed HEAD version of lockapp.py, loaded from
git and run through the identical fake, so the comparison is against what was actually deployed-in-repo,
not a hand-copied expectation."""
import hashlib
import hmac
import importlib.util
import json
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

import lockapp  # noqa: E402  (working tree version)

SECRET = "test-secret"
NOW = 1_800_000_000
UID, COACH = "trainee1", "coach1"
CMD = "c" * 32


def load_head():
    src = subprocess.check_output(
        ["git", "show", "HEAD:cloudrunfunctions/lockapp.py"], cwd=REPO
    ).decode()
    mod = types.ModuleType("lockapp_head")
    exec(compile(src, "lockapp_head.py", "exec"), mod.__dict__)
    return mod


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


class FakeDB:
    def __init__(self, users):
        self.users = users
        self.sets = []  # (collection, doc, data, kwargs)

    def collection(self, name):
        db = self

        class Col:
            def document(self, doc):
                class Doc:
                    def set(_s, data, **kw):
                        db.sets.append((name, doc, data, kw))

                    def get(_s):
                        return FakeSnap(db.users.get(doc) if name == "users" else None)

                return Doc()

        return Col()


class FakeMessaging:
    """Plain recorders so payloads are comparable values rather than MagicMocks."""

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
    SERVER_TIMESTAMP = "<SERVER_TS>"

    def __init__(self, db):
        self._db = db

    def client(self):
        return self._db


def sign(uid=UID, coach=COACH, ts=NOW, secret=SECRET):
    return hmac.new(secret.encode(), f"{uid}|{coach}|{ts}".encode(), hashlib.sha256).hexdigest()


class Req:
    def __init__(self, args):
        self.args = args


def call(mod, args, alert_push=False):
    db = FakeDB({
        COACH: {"name": "Coach Carter"},
        UID: {"fcmToken": "tok"},
    })
    fm = FakeMessaging()
    with mock.patch.object(mod, "firestore", FakeFirestoreMod(db)), \
            mock.patch.object(mod, "messaging", fm), \
            mock.patch.object(mod, "ALERT_PUSH", alert_push), \
            mock.patch.object(mod.time, "time", lambda: NOW), \
            mock.patch.object(mod.uuid, "uuid4", lambda: types.SimpleNamespace(hex=CMD)), \
            mock.patch.dict(os.environ, {"UNLOCK_SECRET": SECRET}):
        resp = mod.lockApp(Req(args))
    return resp, db, fm


def good_args(**extra):
    a = {"uid": UID, "coach": COACH, "ts": str(NOW), "sig": sign()}
    a.update(extra)
    return a


def lock_command_write(db):
    w = [s for s in db.sets if s[0] == "userSettings"]
    assert len(w) == 1, db.sets
    return w[0][2]["lockCommand"]


class WithMessage(unittest.TestCase):
    def test_message_written_and_pushed(self):
        resp, db, fm = call(lockapp, good_args(msg="  stay   focused\n"))
        self.assertEqual(resp[1], 200)
        self.assertEqual(lock_command_write(db)["message"], "stay focused")
        (_, kw), = fm.sent
        self.assertEqual(kw["data"]["message"], "stay focused")
        self.assertEqual(kw["data"]["type"], "lock")

    def test_message_becomes_alert_body_when_alert_push(self):
        _, _, fm = call(lockapp, good_args(msg="hello"), alert_push=True)
        (_, kw), = fm.sent
        alert = kw["apns"][1]["payload"][1]["aps"][1]["alert"][1]
        self.assertEqual(alert["body"], "hello")

    def test_over_long_message_truncated_not_rejected(self):
        resp, db, fm = call(lockapp, good_args(msg="x" * 500))
        self.assertEqual(resp[1], 200)
        self.assertEqual(lock_command_write(db)["message"], "x" * 100)

    def test_blank_message_treated_as_absent(self):
        resp, db, fm = call(lockapp, good_args(msg="   \n "))
        self.assertEqual(resp[1], 200)
        self.assertNotIn("message", lock_command_write(db))
        self.assertNotIn("message", fm.sent[0][1]["data"])


class WithoutMessageUnchanged(unittest.TestCase):
    def _compare(self, alert_push):
        head = load_head()
        r_old, db_old, fm_old = call(head, good_args(), alert_push)
        r_new, db_new, fm_new = call(lockapp, good_args(), alert_push)
        self.assertEqual(r_new, r_old)
        # byte-for-byte: serialise with sorted keys and compare the strings
        dump = lambda o: json.dumps(o, sort_keys=True, default=repr)
        self.assertEqual(dump(db_new.sets), dump(db_old.sets))
        self.assertEqual(dump(fm_new.sent), dump(fm_old.sent))
        return db_new, fm_new

    def test_silent_push_identical_to_head(self):
        db, fm = self._compare(False)
        self.assertNotIn("message", lock_command_write(db))
        self.assertEqual(
            set(fm.sent[0][1]["data"]), {"type", "by", "byName", "cmd", "uid"}
        )

    def test_alert_push_identical_to_head(self):
        self._compare(True)

    def test_empty_msg_param_identical_to_head(self):
        head = load_head()
        _, db_old, fm_old = call(head, good_args())
        _, db_new, fm_new = call(lockapp, good_args(msg=""))
        dump = lambda o: json.dumps(o, sort_keys=True, default=repr)
        self.assertEqual(dump(db_new.sets), dump(db_old.sets))
        self.assertEqual(dump(fm_new.sent), dump(fm_old.sent))


class Signature(unittest.TestCase):
    def test_good_signature_without_msg_in_signed_string_accepted(self):
        # sig covers only uid|coach|ts; adding msg must not invalidate it
        for extra in ({}, {"msg": "hi there"}):
            resp, db, _ = call(lockapp, good_args(**extra))
            self.assertEqual(resp[1], 200, extra)

    def test_bad_signature_rejected_with_and_without_msg(self):
        for extra in ({}, {"msg": "hi"}):
            args = good_args(**extra)
            args["sig"] = "0" * 64
            resp, db, fm = call(lockapp, args)
            self.assertEqual(resp[1], 403, extra)
            self.assertEqual(db.sets, [], "nothing may be written on a bad signature")
            self.assertEqual(fm.sent, [])

    def test_signature_that_includes_msg_is_rejected(self):
        args = good_args(msg="hi")
        args["sig"] = hmac.new(
            SECRET.encode(), f"{UID}|{COACH}|{NOW}|hi".encode(), hashlib.sha256
        ).hexdigest()
        resp, db, _ = call(lockapp, args)
        self.assertEqual(resp[1], 403)
        self.assertEqual(db.sets, [])

    def test_msg_not_cleaned_or_stored_before_signature_check(self):
        args = good_args(msg="hi")
        args["sig"] = "bad"
        with mock.patch.object(lockapp, "_clean_message") as cm:
            resp, _, _ = call(lockapp, args)
        self.assertEqual(resp[1], 403)
        cm.assert_not_called()


if __name__ == "__main__":
    unittest.main()
