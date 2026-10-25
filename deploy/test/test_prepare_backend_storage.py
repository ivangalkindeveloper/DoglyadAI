from __future__ import annotations

import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from prepare_backend_storage import prepare_backend_storage


class BackendStorageTests(unittest.TestCase):
    def test_credentials_are_read_only_for_app_group_and_logs_are_writable(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name in ("secrets", "logs"):
                (root / name).mkdir()
            credential = root / "secrets" / "firebase.json"
            credential.write_text("synthetic")
            log = root / "logs" / "backend.log"
            log.touch()
            with patch("os.geteuid", return_value=0), patch("os.chown") as chown:
                prepare_backend_storage(root)
            self.assertEqual(stat.S_IMODE(credential.stat().st_mode), 0o640)
            self.assertEqual(stat.S_IMODE((root / "secrets").stat().st_mode), 0o750)
            self.assertEqual(stat.S_IMODE(log.stat().st_mode), 0o660)
            self.assertEqual(
                stat.S_IMODE((root / "logs").stat().st_mode) & 0o777, 0o770
            )
            self.assertTrue(
                all(call.args[1:] == (-1, 10001) for call in chown.call_args_list)
            )

    def test_non_root_helper_is_rejected(self) -> None:
        with (
            patch("os.geteuid", return_value=10001),
            self.assertRaises(PermissionError),
        ):
            prepare_backend_storage(Path("unused"))

    def test_symlink_cannot_change_permissions_outside_mounted_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "secrets").mkdir()
            (root / "logs").mkdir()
            outside = root / "outside"
            outside.touch(mode=0o600)
            (root / "secrets" / "link").symlink_to(outside)
            with (
                patch("os.geteuid", return_value=0),
                patch("os.chown"),
                self.assertRaises(ValueError),
            ):
                prepare_backend_storage(root)
            self.assertEqual(stat.S_IMODE(outside.stat().st_mode), 0o600)


if __name__ == "__main__":
    unittest.main()
