"""Verify recovery and renewal against a real Robokassa test purchase.

Receipts contain hashes and ledger facts, never access or recovery secrets.
Maestro diagnostic text is scrubbed before the owned environment is removed.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess

from payment_evidence import owner_ids, verify_payment

ACTIONS = (
    "cancel-renewal",
    "copy-key",
    "copy-key-again",
    "reject-invalid-key",
    "restore-key",
)


def redact_recovery_diagnostics(root: Path):
    """Remove displayed recovery keys from Maestro's accessibility diagnostics."""
    pattern = re.compile(r"(?<![A-Fa-f0-9])[A-F0-9]{48}(?![A-Fa-f0-9])")
    for path in root.rglob("*"):
        if path.suffix not in {".json", ".log", ".xml", ".txt", ".html"}:
            continue
        if not any("subscriptionrecovery" in part.lower() for part in path.parts):
            continue
        original = path.read_text(errors="replace")
        redacted = pattern.sub("[recovery-key-redacted]", original)
        if redacted != original:
            path.write_text(redacted)


class SubscriptionEvidence:
    def __init__(self, project: str, environment: dict[str, str]):
        if not project.startswith("doglyad-regression-"):
            raise ValueError("Subscription evidence requires an isolated project")
        self.project = project
        self.environment = environment
        self.baseline = None
        self.purchase = None
        self.completed: list[str] = []
        self.original_key = ""
        self.current_key = ""
        self.owners_before_reset: set[str] = set()

    def query(self, query: str):
        result = subprocess.check_output(
            [
                "docker",
                "exec",
                self.project + "-database-1",
                "psql",
                "-U",
                "regression",
                "-d",
                "regression",
                "-tA",
                "-c",
                query,
            ],
            text=True,
        ).strip()
        if not result:
            raise ValueError("Missing subscription evidence")
        return json.loads(result)

    def snapshot(self):
        owner = (
            "(SELECT id FROM billing_owners ORDER BY created_at DESC LIMIT 1)"
            if self.baseline is None
            else "'" + self.baseline["owner_id"] + "'"
        )
        return self.query(f"""
            SELECT row_to_json(evidence) FROM (
              SELECT s.id, s.owner_id, s.plan_id, s.source, s.entitlement,
                     s.paid_until, s.is_auto_renewing, s.is_revoked,
                     s.paid_until > now() AS is_active, o.recovery_hash,
                     (SELECT count(*) FROM billing_credentials c
                      WHERE c.owner_id = s.owner_id) AS credentials,
                     (SELECT count(*) FROM billing_payments p
                      WHERE p.owner_id = s.owner_id) AS payments
              FROM billing_subscriptions s JOIN billing_owners o ON o.id = s.owner_id
              WHERE s.owner_id = {owner} ORDER BY s.updated_at DESC LIMIT 1
            ) evidence
        """)

    @staticmethod
    def copy(device: str, text: str):
        subprocess.run(
            ["xcrun", "simctl", "pbcopy", device],
            input=text,
            text=True,
            check=True,
            stdout=subprocess.DEVNULL,
        )

    def before(self, action: str, device: str):
        if (
            action not in ACTIONS
            or tuple(self.completed) != ACTIONS[: ACTIONS.index(action)]
        ):
            raise ValueError(
                "Subscription actions must run once in their declared order"
            )
        if self.baseline is None:
            self.purchase = verify_payment(self.project, "pro_weekly", self.environment)
            self.baseline = self.snapshot()
            if not self.baseline["is_auto_renewing"]:
                raise ValueError("The test purchase must initially support renewal")
        if action == "reject-invalid-key":
            self.owners_before_reset = owner_ids(self.project)
            self.copy(device, "F" * 48 if self.current_key != "F" * 48 else "E" * 48)
        elif action == "restore-key":
            self.copy(device, self.current_key)
        else:
            self.copy(device, "regression-not-copied")

    def after(self, action: str, device: str):
        state = self.snapshot()
        preserved = (
            "id",
            "owner_id",
            "plan_id",
            "source",
            "entitlement",
            "paid_until",
            "is_revoked",
            "is_active",
            "payments",
        )
        if (
            any(state[key] != self.baseline[key] for key in preserved)
            or state["is_auto_renewing"]
        ):
            raise ValueError(
                "Subscription action changed paid access or created a payment"
            )
        proof = dict(
            self.purchase,
            status="action-passed",
            action=action,
            paidPeriodUnchanged=True,
            paymentCountUnchanged=True,
            active=True,
            autoRenewing=False,
        )
        if action in {"copy-key", "copy-key-again"}:
            key = subprocess.check_output(
                ["xcrun", "simctl", "pbpaste", device], text=True
            ).strip()
            if not re.fullmatch(r"[A-F0-9]{48}", key):
                raise ValueError("Copy did not produce a complete recovery key")
            digest = hashlib.sha256(key.encode()).hexdigest()
            if state["recovery_hash"] != digest or self.baseline["recovery_hash"] != digest:
                raise ValueError("Copied key does not match the permanent backend key")
            if action == "copy-key-again" and key != self.original_key:
                raise ValueError("Repeated copying changed the recovery key")
            if action == "copy-key":
                self.original_key = key
            self.current_key = key
            proof.update(copiedKeyVerified=True, keyStable=True, keySha256=digest)
        elif action in {"reject-invalid-key", "restore-key"}:
            new_owners = owner_ids(self.project) - self.owners_before_reset
            if len(new_owners) != 1:
                raise ValueError("Recovery requires a new clean client identity")
            new_owner = next(iter(new_owners))
            # IDs came from PostgreSQL, but validate before embedding in SQL.
            if not re.fullmatch(r"[a-f0-9-]{36}", new_owner):
                raise ValueError("Invalid recovery owner identity")
            counts = self.query(f"""SELECT json_build_object(
              'payments', (SELECT count(*) FROM billing_payments WHERE owner_id = '{new_owner}'),
              'subscriptions', (SELECT count(*) FROM billing_subscriptions WHERE owner_id = '{new_owner}'))""")
            expected_credentials = self.baseline["credentials"] + int(
                action == "restore-key"
            )
            if state["credentials"] != expected_credentials or any(counts.values()):
                raise ValueError(
                    "Recovery duplicated access or authorized the rejected key"
                )
            proof.update(
                cleanClient=True,
                originalOwnerRetained=True,
                credentialsAdded=int(action == "restore-key"),
                invalidKeyRejected=action == "reject-invalid-key",
            )
        elif state["credentials"] != self.baseline["credentials"]:
            raise ValueError("Renewal cancellation unexpectedly created credentials")
        self.completed.append(action)
        self.copy(device, "")
        return proof

    def clear(self, device: str | None):
        self.original_key = self.current_key = ""
        if device:
            self.copy(device, "")
