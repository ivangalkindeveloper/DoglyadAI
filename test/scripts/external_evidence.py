"""Check the exact URL handed to a simulator-only external application adapter."""

import hashlib
import json
from pathlib import Path
import subprocess
from urllib.parse import parse_qs, urlparse


def snapshot(device: str, app_id: str) -> dict:
    container = Path(
        subprocess.check_output(
            ["xcrun", "simctl", "get_app_container", device, app_id, "data"], text=True
        ).strip()
    )
    return {
        p.name: json.loads(p.read_text())
        for p in (container / "Documents/RegressionExternalActions").glob("*.json")
    }


def verify(
    before: dict, after: dict, expected: list[dict], delivered: list[dict] | None = None
) -> dict:
    events = [value for key, value in after.items() if key not in before]
    if len(events) != len(expected):
        raise ValueError("Wrong number of external application actions")
    catalog = json.loads(
        (
            Path(__file__).resolve().parents[1] / "fixtures/development/ru.json"
        ).read_text()
    )
    config = catalog["application"]
    receipts = []
    for event, condition in zip(events, expected):
        if (
            event.get("canceled") is not True
            or event.get("adapter") != "external-application"
        ):
            raise ValueError("External application cancellation was not observed")
        url = urlparse(event["url"])
        query = parse_qs(url.query, keep_blank_values=True)
        subject = query.get("subject", [""])[0]
        body = query.get("body", [""])[0]
        if condition["kind"] == "store":
            if event["url"] != config["appleUpdateUrl"] + config["appStoreId"]:
                raise ValueError(
                    "App Store URL does not identify the configured application"
                )
        elif condition["kind"] == "report":
            matches = [
                message
                for message in delivered or []
                if condition["patientName"] in message["subject"]
            ]
            if not matches or url.scheme != "mailto" or url.path:
                raise ValueError("No delivered report matches the external email")
            latest = matches[-1]
            if subject != latest["subject"] or body.rstrip("\n") != latest[
                "body"
            ].replace("\r\n", "\n").rstrip("\n"):
                raise ValueError("External email differs from the verified SMTP report")
        else:
            recipient = config["contactEmail"] if condition["kind"] == "support" else ""
            if (
                url.scheme != "mailto"
                or url.path != recipient
                or subject != condition.get("subject", "")
            ):
                raise ValueError("Email URL uses the wrong recipient or subject")
            if any(
                fragment not in body for fragment in condition.get("bodyContains", [])
            ):
                raise ValueError("External email does not contain the expected report")
        receipts.append(
            dict(
                kind=condition["kind"],
                canceled=True,
                urlSha256=hashlib.sha256(event["url"].encode()).hexdigest(),
                bodySha256=hashlib.sha256(body.encode()).hexdigest(),
            )
        )
    return dict(
        status="passed",
        adapter="external-application",
        expected=expected,
        actions=receipts,
    )
