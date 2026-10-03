import sys
import types
import unittest
from unittest import mock

# lockapp initialises firebase at import; stub the SDK so the pure helper is testable offline.
for name in ("firebase_functions", "firebase_admin"):
    sys.modules.setdefault(name, mock.MagicMock())
sys.modules["firebase_functions"].https_fn.on_request = lambda *a, **k: (lambda f: f)
sys.modules["firebase_admin"]._apps = [1]

import lockapp  # noqa: E402

clean = lockapp._clean_message


class CleanMessageTests(unittest.TestCase):
    def test_absent_and_empty(self):
        self.assertIsNone(clean(None))
        self.assertIsNone(clean(""))
        self.assertIsNone(clean("  \n\t "))
        self.assertIsNone(clean(5))

    def test_collapses_whitespace_and_controls(self):
        self.assertEqual(clean("  hi\n\nthere\x00\x07 you  "), "hi there you")

    def test_zwj_emoji_survive(self):
        family = "\U0001F468‍\U0001F469‍\U0001F467"
        self.assertEqual(clean(f"a {family} b"), f"a {family} b")

    def test_truncates_at_100_code_points(self):
        self.assertEqual(clean("x" * 150), "x" * 100)
        self.assertEqual(clean("x" * 99 + " " + "y" * 10), "x" * 99)  # cut leaves no trailing space


if __name__ == "__main__":
    unittest.main()
