from http.client import RemoteDisconnected
from pathlib import Path
import sys
import unittest
import urllib.error
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from regression import wait_backend

URL = "http://127.0.0.1:18765/v1/application_config"


class ReadinessTests(unittest.TestCase):
    def setUp(self):
        self.now = 0

        def advance(seconds):
            self.now += seconds

        for context in (
            patch("regression.time.monotonic", side_effect=lambda: self.now),
            patch("regression.time.sleep", side_effect=advance),
            patch("builtins.print"),
        ):
            context.start()
            self.addCleanup(context.stop)

    def rejection(self, status=401):
        return urllib.error.HTTPError(URL, status, "Rejected", None, None)

    def test_closed_startup_connection_is_retried_until_auth_rejection(self):
        with patch(
            "regression.urllib.request.urlopen",
            side_effect=[
                RemoteDisconnected("Remote end closed connection without response"),
                self.rejection(),
            ],
        ) as request:
            wait_backend()
        self.assertEqual(request.call_count, 2)
        request.assert_called_with(URL, timeout=3)
        self.assertEqual(self.now, 1)

    def test_transient_transport_and_http_failures_can_recover(self):
        with patch(
            "regression.urllib.request.urlopen",
            side_effect=[
                ConnectionResetError(),
                TimeoutError(),
                urllib.error.URLError(ConnectionRefusedError()),
                self.rejection(503),
                self.rejection(403),
            ],
        ) as request:
            wait_backend()
        self.assertEqual(request.call_count, 5)

    def test_success_without_app_check_is_never_accepted(self):
        with patch(
            "regression.urllib.request.urlopen", return_value=MagicMock()
        ) as request:
            with self.assertRaisesRegex(RuntimeError, "Unauthenticated configuration"):
                wait_backend()
        self.assertEqual(request.call_count, 1)

    def test_repeated_disconnections_stop_at_deadline_with_diagnostics(self):
        with patch(
            "regression.urllib.request.urlopen", side_effect=RemoteDisconnected()
        ) as request:
            with self.assertRaisesRegex(
                RuntimeError, "within 2s; last probe: RemoteDisconnected"
            ):
                wait_backend(timeout=2)
        self.assertEqual(request.call_count, 2)
        self.assertEqual(self.now, 2)

    def test_repeated_http_errors_do_not_mark_backend_ready(self):
        with patch(
            "regression.urllib.request.urlopen", side_effect=self.rejection(500)
        ):
            with self.assertRaisesRegex(RuntimeError, "HTTP 500"):
                wait_backend(timeout=2)
