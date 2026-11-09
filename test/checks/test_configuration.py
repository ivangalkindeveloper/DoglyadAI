from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from artifacts import suite_hash
from regression import configuration

TOKEN_NAME = "REGRESSION_APP_CHECK_DEBUG_TOKEN"


class ConfigurationTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.test = self.root / "test"
        (self.test / "secrets").mkdir(parents=True)
        self.env_file = self.test / "secrets/.env"
        (self.root / "firebase.json").write_text("{}")
        (self.test / "secrets/config.local.json").write_text(
            json.dumps(
                {
                    "firebaseCredentials": "firebase.json",
                    "appId": "com.medical.doglyad.local",
                    "scheme": "Doglyad-Debug-Local",
                }
            )
        )
        for context in (
            patch("regression.ROOT", self.root),
            patch("regression.TEST", self.test),
            patch("regression._is_local_app_check_configured", return_value=False),
            patch.dict(os.environ, {}, clear=True),
        ):
            context.start()
            self.addCleanup(context.stop)

    def test_file_token_is_available_to_the_runner_environment(self):
        self.env_file.write_text(f'# Local token\n{TOKEN_NAME}="file-token"\n')
        config = configuration()
        self.assertEqual(os.environ[TOKEN_NAME], "file-token")
        self.assertNotIn("file-token", json.dumps(config))
        self.assertEqual(config["backendBuildTimeoutSeconds"], 3600)
        self.assertEqual(
            config["firebaseCredentials"], str((self.root / "firebase.json").resolve())
        )

    def test_process_environment_overrides_the_file(self):
        self.env_file.write_text(f"{TOKEN_NAME}=file-token\n")
        os.environ[TOKEN_NAME] = "environment-token"
        configuration()
        self.assertEqual(os.environ[TOKEN_NAME], "environment-token")

    def test_file_is_optional_when_the_environment_has_a_token(self):
        os.environ[TOKEN_NAME] = "environment-token"
        configuration()
        self.assertEqual(os.environ[TOKEN_NAME], "environment-token")

    def test_empty_token_fails_with_the_config_location(self):
        self.env_file.write_text(f"{TOKEN_NAME}=\n")
        with self.assertRaisesRegex(ValueError, r"test/secrets/\.env"):
            configuration()

    def test_local_ios_config_is_sufficient_without_a_regression_override(self):
        with patch("regression._is_local_app_check_configured", return_value=True):
            config = configuration()
        self.assertNotIn(TOKEN_NAME, os.environ)
        self.assertNotIn("APP_CHECK_DEBUG_TOKEN", json.dumps(config))

    def test_empty_override_uses_the_local_ios_config(self):
        self.env_file.write_text(f"{TOKEN_NAME}=\n")
        with patch("regression._is_local_app_check_configured", return_value=True):
            configuration()

    def test_explicit_override_does_not_need_xcode_preflight(self):
        os.environ[TOKEN_NAME] = "environment-token"
        with patch("regression._is_local_app_check_configured") as resolve:
            configuration()
        resolve.assert_not_called()

    def test_backend_build_timeout_can_be_configured(self):
        path = self.test / "secrets/config.local.json"
        config = json.loads(path.read_text())
        config["backendBuildTimeoutSeconds"] = 7200
        path.write_text(json.dumps(config))
        os.environ[TOKEN_NAME] = "environment-token"
        self.assertEqual(configuration()["backendBuildTimeoutSeconds"], 7200)

    def test_invalid_backend_build_timeout_is_rejected(self):
        path = self.test / "secrets/config.local.json"
        config = json.loads(path.read_text())
        for value in (0, -1, True, "3600", 1.5):
            with self.subTest(value=value):
                config["backendBuildTimeoutSeconds"] = value
                path.write_text(json.dumps(config))
                with self.assertRaisesRegex(ValueError, "backendBuildTimeoutSeconds"):
                    configuration()

    def test_file_values_are_not_interpolated_or_executed(self):
        literal = "${OTHER_SECRET}$(printf unexpected)"
        self.env_file.write_text(f"{TOKEN_NAME}='{literal}'\n")
        os.environ["OTHER_SECRET"] = "unrelated-secret"
        configuration()
        self.assertEqual(os.environ[TOKEN_NAME], literal)

    def test_secret_changes_do_not_enter_the_suite_hash(self):
        (self.test / "case.yaml").write_text("public test contents")
        with patch("artifacts.TEST", self.test):
            before = suite_hash()
            self.env_file.write_text(f"{TOKEN_NAME}=file-token\n")
            self.assertEqual(suite_hash(), before)
            (self.test / "secrets/firebase.json").write_text("private credentials")
            self.assertEqual(suite_hash(), before)
            (self.test / "secrets/config.local.json").write_text("private local config")
            self.assertEqual(suite_hash(), before)
            (self.test / "case.yaml").write_text("changed test contents")
            self.assertNotEqual(suite_hash(), before)


if __name__ == "__main__":
    unittest.main()
