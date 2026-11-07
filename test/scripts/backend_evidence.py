"""Compare UI-triggered requests with expected settings and completed backend jobs."""

import hashlib
import json
from pathlib import Path
import re
import subprocess


def verify_requests(events: list[dict], expected: dict, project: str) -> dict:
    if not project.startswith("doglyad-regression-"):
        raise ValueError("Backend evidence requires the isolated regression project")
    posts = [
        event
        for event in events
        if event["method"] == "POST"
        and event["path"] == "/v1/ultrasound/report_generations"
    ]
    if expected.get("dictationText"):
        dictations = [
            item
            for item in events
            if item["method"] == "POST"
            and item["path"] == "/v1/ultrasound/parse_dictation"
        ]
        matches = [
            item
            for item in dictations
            if item.get("request", {}).get("transcript") == expected["dictationText"]
            and item["status"] == 200
            and not item.get("unreadable")
            and not item.get("truncated")
        ]
        if (
            posts
            or len(matches) != 1
            or any(
                not item.get("request", {}).get("transcript", "").strip()
                for item in dictations
            )
        ):
            raise ValueError(
                "The edited transcript did not reach the protected parsing endpoint exactly once"
            )
        return {
            "status": "passed",
            "generationRequests": 0,
            "dictationRequests": len(dictations),
            "expected": expected,
        }
    if expected.get("absent"):
        if posts:
            raise ValueError("Invalid form sent an unexpected generation request")
        if expected.get("emailAbsent") and any(
            event["method"] == "POST" and event["path"] == "/v1/send_report_email"
            for event in events
        ):
            raise ValueError("Restricted or canceled flow attempted SMTP delivery")
        if expected.get("dictationAbsent") and any(
            event["method"] == "POST"
            and event["path"] == "/v1/ultrasound/parse_dictation"
            for event in events
        ):
            raise ValueError("Cancelled speech flow still sent a parsing request")
        return {"status": "passed", "generationRequests": 0, "expected": expected}
    if expected.get("attemptStatuses"):
        return verify_attempts(events, posts, expected, project)
    if len(posts) != 1:
        raise ValueError("Expected exactly one report generation request")
    event = posts[0]
    request = event["request"]
    if event.get("truncated") or event.get("unreadable") or event["status"] != 202:
        raise ValueError("Generation request did not reach the real protected backend")
    for key, value in expected.items():
        if key in {"reportSections", "jobStatus"}:
            continue
        elif key == "settingsAI":
            if any(
                request[key].get(field) != setting for field, setting in value.items()
            ):
                raise ValueError(
                    "Actual generation settings differ from the saved UI settings"
                )
        elif key == "templateId":
            fixtures = json.loads(
                (
                    Path(__file__).resolve().parents[1] / "fixtures/development/ru.json"
                ).read_text()
            )
            template = next(
                item for item in fixtures["readyMadeTemplates"] if item["id"] == value
            )
            if request.get("template") != template["content"]:
                raise ValueError(
                    "The selected template did not reach the backend intact"
                )
        elif request.get(key) != value:
            raise ValueError(f"Actual generation parameter differs: {key}")
    identity = event["response"].get("generationId", "")
    if not re.fullmatch(r"[a-fA-F0-9-]{36}", identity):
        raise ValueError("Missing report job identity")
    query = (
        "SELECT row_to_json(evidence) FROM (SELECT id, request_id, status, model_id FROM report_generations WHERE id = '"
        + identity
        + "') evidence"
    )
    raw = subprocess.check_output(
        [
            "docker",
            "exec",
            project + "-database-1",
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
    )
    job = json.loads(raw)
    if (
        job["status"] != expected.get("jobStatus", "completed")
        or job["request_id"].casefold() != request["requestId"].casefold()
        or job["model_id"] != request["settingsAI"]["selectedNeuralModelId"]
    ):
        raise ValueError("The expected backend report job did not complete")
    if expected.get("reportSections"):
        completed = [
            item["response"]
            for item in events
            if item.get("response", {}).get("generationId") == identity
            and item["response"].get("status") == "completed"
        ]
        if not completed or not completed[-1].get("report"):
            raise ValueError("The client did not receive the completed report snapshot")
        report = completed[-1]["report"]
        if any(
            bool(report.get(field)) != enabled
            for field, enabled in expected["reportSections"].items()
        ):
            raise ValueError(
                "Returned report sections differ from the saved user settings"
            )
    return {
        "status": "passed",
        "generationRequests": 1,
        "generationId": identity,
        "requestId": job["request_id"],
        "modelId": job["model_id"],
        "requestSha256": hashlib.sha256(
            json.dumps(request, sort_keys=True).encode()
        ).hexdigest(),
        "expected": expected,
    }


def verify_attempts(
    events: list[dict], posts: list[dict], expected: dict, project: str
) -> dict:
    statuses = expected["attemptStatuses"]
    if (
        len(posts) != len(statuses)
        or not statuses
        or any(status not in {"failed", "completed"} for status in statuses)
    ):
        raise ValueError("Unexpected report generation attempt count or status")
    common = {
        key: value
        for key, value in expected.items()
        if key not in {"attemptStatuses", "partialAttempt", "worker"}
    }
    attempts = []
    identities = set()
    request_ids = set()
    for index, (post, status) in enumerate(zip(posts, statuses)):
        assertion = {**common, "jobStatus": status}
        if status != "completed":
            assertion.pop("reportSections", None)
        selected = [post] + [item for item in events if item["method"] != "POST"]
        evidence = verify_requests(selected, assertion, project)
        identity = evidence["generationId"]
        if identity in identities or evidence["requestId"].casefold() in request_ids:
            raise ValueError("Retry reused an earlier generation or request identity")
        identities.add(identity)
        request_ids.add(evidence["requestId"].casefold())
        snapshots = [item.get("response", {}) for item in events]
        snapshots += [
            snapshot for item in events for snapshot in item.get("streamSnapshots", [])
        ]
        matching = [
            snapshot
            for snapshot in snapshots
            if snapshot.get("generationId", "").casefold() == identity.casefold()
        ]
        if not any(snapshot.get("status") == status for snapshot in matching):
            raise ValueError(
                "Client did not receive the terminal state of each generation attempt"
            )
        if expected.get("partialAttempt") == index and not any(
            (snapshot.get("partialReport") or {}).get("description")
            for snapshot in matching
        ):
            raise ValueError(
                "The interrupted attempt did not deliver a real partial report"
            )
        attempts.append({**evidence, "jobStatus": status})
    if len(posts) > 1:
        original = {
            key: value
            for key, value in posts[0]["request"].items()
            if key != "requestId"
        }
        if any(
            {key: value for key, value in item["request"].items() if key != "requestId"}
            != original
            for item in posts[1:]
        ):
            raise ValueError(
                "Retry changed the original examination or generation settings"
            )
    return {
        "status": "passed",
        "generationRequests": len(posts),
        "generationId": attempts[0]["generationId"],
        "attempts": attempts,
        "expected": expected,
    }
