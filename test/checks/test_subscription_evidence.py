import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from subscription_evidence import SubscriptionEvidence, redact_recovery_diagnostics


class SubscriptionEvidenceTests(unittest.TestCase):
    def test_diagnostics_redact_keys_but_preserve_receipt_hashes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = root / "e2e-subscriptionrecovery-restore-key"
            folder.mkdir()
            key = "A" * 48
            digest = hashlib.sha256(key.encode()).hexdigest()
            log = folder / "commands.json"
            log.write_text('{"text":"' + key + '","sha256":"' + digest + '"}')
            other = root / "other.json"
            other.write_text(key)
            redact_recovery_diagnostics(root)
            self.assertNotIn(key, log.read_text())
            self.assertIn(digest, log.read_text())
            self.assertEqual(other.read_text(), key)

    def session(self):
        session = SubscriptionEvidence("doglyad-regression-unit", {})
        session.baseline = dict(
            id="subscription",
            owner_id="owner",
            plan_id="pro_weekly",
            source="robokassa",
            entitlement="pro",
            paid_until="future",
            is_auto_renewing=True,
            is_revoked=False,
            is_active=True,
            payments=1,
            credentials=1,
            recovery_hash=None,
        )
        session.purchase = dict(
            provider="robokassa", test=True, status="succeeded", planId="pro_weekly"
        )
        return session

    def test_cancel_cannot_shorten_access_or_create_another_payment(self):
        session = self.session()
        state = dict(session.baseline, is_auto_renewing=False)
        with (
            patch.object(session, "copy"),
            patch.object(session, "snapshot", return_value=state),
        ):
            self.assertTrue(
                session.after("cancel-renewal", "sim")["paidPeriodUnchanged"]
            )
        for change in [
            dict(paid_until="another-date"),
            dict(payments=2),
            dict(is_active=False),
            dict(is_auto_renewing=True),
            dict(credentials=2),
        ]:
            with (
                patch.object(session, "copy"),
                patch.object(session, "snapshot", return_value=dict(state, **change)),
                self.assertRaises(ValueError),
            ):
                session.after("cancel-renewal", "sim")

    def test_key_copy_is_bound_to_the_permanent_backend_hash(self):
        session = self.session()
        key = "A" * 48
        state = dict(
            session.baseline,
            is_auto_renewing=False,
            recovery_hash=hashlib.sha256(key.encode()).hexdigest(),
        )
        session.baseline["recovery_hash"] = state["recovery_hash"]
        with (
            patch.object(session, "copy"),
            patch.object(session, "snapshot", return_value=state),
            patch("subscription_evidence.subprocess.check_output", return_value=key),
        ):
            proof = session.after("copy-key", "sim")
            self.assertTrue(proof["copiedKeyVerified"])
            self.assertNotIn(key, str(proof))
            self.assertTrue(session.after("copy-key-again", "sim")["keyStable"])
            with patch("subscription_evidence.subprocess.check_output", return_value="B" * 48), self.assertRaises(ValueError):
                session.after("copy-key-again", "sim")

    def test_recovery_requires_new_identity_one_credential_and_no_new_period(self):
        session = self.session()
        session.owners_before_reset = {"owner"}
        new = "12345678-1234-1234-1234-123456789abc"
        state = dict(session.baseline, is_auto_renewing=False)
        with (
            patch.object(session, "copy"),
            patch("subscription_evidence.owner_ids", return_value={"owner", new}),
            patch.object(
                session, "query", return_value=dict(payments=0, subscriptions=0)
            ),
        ):
            with patch.object(session, "snapshot", return_value=state):
                self.assertTrue(
                    session.after("reject-invalid-key", "sim")["invalidKeyRejected"]
                )
                with self.assertRaises(ValueError):
                    session.after("restore-key", "sim")
            with patch.object(
                session, "snapshot", return_value=dict(state, credentials=2)
            ):
                self.assertEqual(
                    session.after("restore-key", "sim")["credentialsAdded"], 1
                )
                with self.assertRaises(ValueError):
                    session.after("reject-invalid-key", "sim")

    def test_out_of_order_actions_are_rejected_before_ui(self):
        session = self.session()
        with self.assertRaises(ValueError):
            session.before("restore-key", "sim")


if __name__ == "__main__":
    unittest.main()
