"""Verify the actual clipboard and local SMTP delivery for the same generated report."""

from pathlib import Path
import hashlib
import json
import subprocess


def mail_status(compose: list[str], environment: dict) -> dict:
    return json.loads(
        subprocess.check_output(
            [*compose, "exec", "-T", "mail", "python", "receiver.py", "status"],
            env=environment,
            text=True,
        )
    )


def verify_delivery(before: dict, after: dict, clipboard: str, expected: dict) -> dict:
    previous = {message["id"] for message in before["messages"]}
    messages = [
        message for message in after["messages"] if message["id"] not in previous
    ]
    if len(messages) != 1 or after["pendingFailure"]:
        raise ValueError("Expected exactly one accepted SMTP message")
    if after["rejectedCount"] - before["rejectedCount"] != int(expected["failNext"]):
        raise ValueError("The expected SMTP failure was not exercised")
    message = messages[0]
    body = message["body"].replace("\r\n", "\n").rstrip("\n")
    clipboard = clipboard.replace("\r\n", "\n").rstrip("\n")
    fixture = json.loads(
        (
            Path(__file__).resolve().parents[2] / "backend/main/mock/ru/report.json"
        ).read_text()
    )["report"]
    mode = expected.get("clipboardMode", "full-report")
    if mode == "model-report":
        catalog = json.loads((Path(__file__).resolve().parents[2] / "backend/main/config/development/ru/l10n_application.json").read_text())
        separator = catalog["reportActualModelResponseTitle"] + "\n"
        model_text = body.split(separator, 1)[1] if separator in body else ""
        clipboard_matches = bool(model_text) and clipboard == model_text
    elif mode == "full-report":
        clipboard_matches = body == clipboard
    else:
        raise ValueError("Unknown clipboard content contract")
    if (
        message["recipient"] != expected["recipient"]
        or message["recipients"] != [expected["recipient"]]
        or message["tls"] is not True
        or message["authenticated"] is not True
        or expected["patientName"] not in message["subject"]
        or expected["patientName"] not in body
        or fixture["description"] not in body
        or fixture["conclusion"] not in body
        or not clipboard_matches
    ):
        raise ValueError(
            "SMTP content, clipboard, recipient or transport differs from the report"
        )
    attachments = message["attachments"]
    if len(attachments) != expected["attachmentCount"] or any(
        item["fileName"] != f"ultrasound-{index + 1}.jpg"
        or item["mimeType"] != "image/jpeg"
        or item["isJPEG"] is not True
        or item["size"] <= 1000
        for index, item in enumerate(attachments)
    ):
        raise ValueError("SMTP attachments do not match the report photos")
    return {
        "status": "passed",
        "recipient": expected["recipient"],
        "patientName": expected["patientName"],
        "messagesAccepted": 1,
        "messagesRejected": int(expected["failNext"]),
        "tls": True,
        "authenticated": True,
        "clipboardMatches": True,
        "clipboardMode": mode,
        "bodySha256": hashlib.sha256(body.encode()).hexdigest(),
        "attachments": attachments,
    }
