from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from regression import _is_local_app_check_configured


class AppCheckConfigurationTests(unittest.TestCase):
    def resolved_settings(self, **changes):
        settings = {
            "CONFIGURATION": "Debug-Local",
            "PRODUCT_BUNDLE_IDENTIFIER": "com.medical.doglyad.local",
            "APP_CHECK_DEBUG_TOKEN": "synthetic-local-token",
        }
        settings.update(changes)
        return json.dumps(
            [
                {"target": "DoglyadUI", "buildSettings": {}},
                {"target": "Doglyad", "buildSettings": settings},
            ]
        )

    def test_resolved_local_settings_allow_bundle_token_without_exposing_it(self):
        with patch(
            "regression.subprocess.run",
            return_value=Mock(
                returncode=0,
                stdout=self.resolved_settings(),
            ),
        ) as run:
            self.assertIs(_is_local_app_check_configured(), True)
        self.assertTrue(run.call_args.kwargs["capture_output"])
        self.assertNotIn("synthetic-local-token", repr(run.call_args))

    def test_wrong_configuration_or_unresolved_token_is_rejected(self):
        cases = [
            {"CONFIGURATION": "Debug-Development"},
            {"PRODUCT_BUNDLE_IDENTIFIER": "com.medical.doglyad"},
            {"APP_CHECK_DEBUG_TOKEN": ""},
            {"APP_CHECK_DEBUG_TOKEN": " \n"},
            {"APP_CHECK_DEBUG_TOKEN": "$(APP_CHECK_DEBUG_TOKEN)"},
        ]
        for changes in cases:
            with (
                self.subTest(changes=changes),
                patch(
                    "regression.subprocess.run",
                    return_value=Mock(
                        returncode=0,
                        stdout=self.resolved_settings(**changes),
                    ),
                ),
            ):
                self.assertFalse(_is_local_app_check_configured())

    def test_failed_or_invalid_xcode_output_is_not_printed(self):
        for result in [
            Mock(returncode=65, stdout="synthetic-private-diagnostic"),
            Mock(returncode=0, stdout="invalid JSON"),
        ]:
            with (
                patch("regression.subprocess.run", return_value=result),
                patch("builtins.print") as output,
            ):
                self.assertFalse(_is_local_app_check_configured())
                output.assert_not_called()

    def test_timeout_or_missing_xcode_returns_safe_failure(self):
        for error in [
            FileNotFoundError(),
            subprocess.TimeoutExpired(["synthetic-private-command"], 60),
        ]:
            with patch("regression.subprocess.run", side_effect=error):
                self.assertFalse(_is_local_app_check_configured())
