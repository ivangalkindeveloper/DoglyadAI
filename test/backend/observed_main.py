"""Regression-only ASGI observer. The real application retains every auth/policy check."""

from pathlib import Path
import json
import re
import time
import uuid

from app.main import app as backend

DIRECTORY = Path("/regression-evidence")
MAX_CAPTURE_BYTES = 32 * 1024 * 1024


class RegressionObserver:
    def __init__(self, application):
        self.application = application

    async def __call__(self, scope, receive, send):
        if scope["type"] == "lifespan":

            async def lifecycle(message):
                if message["type"] == "lifespan.startup.complete":
                    DIRECTORY.mkdir(exist_ok=True)
                    (DIRECTORY / "observer-ready.json").write_text(
                        '{"observerVersion": 1}'
                    )
                await send(message)

            await self.application(scope, receive, lifecycle)
            return
        path = scope.get("path", "")
        observed = scope["type"] == "http" and (
            path in {"/v1/ultrasound/parse_dictation", "/v1/send_report_email"}
            or re.fullmatch(
                r"/v1/ultrasound/report_generations(?:/[a-fA-F0-9-]{36}(?:/events)?)?",
                path,
            )
        )
        if not observed:
            await self.application(scope, receive, send)
            return
        incoming = bytearray()
        outgoing = bytearray()
        status = None
        truncated = False

        async def read():
            nonlocal truncated
            message = await receive()
            chunk = message.get("body", b"")
            if len(incoming) + len(chunk) <= MAX_CAPTURE_BYTES:
                incoming.extend(chunk)
            else:
                truncated = True
            return message

        async def write(message):
            nonlocal status, truncated
            if message["type"] == "http.response.start":
                status = message["status"]
            chunk = message.get("body", b"")
            if len(outgoing) + len(chunk) <= MAX_CAPTURE_BYTES:
                outgoing.extend(chunk)
            else:
                truncated = True
            await send(message)

        try:
            await self.application(scope, read, write)
        finally:
            if status is not None:
                event = dict(
                    path=path,
                    method=scope["method"],
                    status=status,
                    truncated=truncated,
                )
                # No headers, bearer secrets, App Check tokens, billing bodies or image bytes.
                try:
                    body = json.loads(incoming) if incoming else {}
                    examination = body.get("examination", {})
                    event["request"] = {
                        key: examination[key]
                        for key in (
                            "settingsAI",
                            "template",
                            "isRecommendationsIncluded",
                            "isPhotoRemarks",
                            "isDescriptionRemarks",
                        )
                        if key in examination
                    }
                    data = examination.get("examinationData", {})
                    event["request"]["examinationData"] = {
                        key: data[key]
                        for key in (
                            "patientName",
                            "examinationNumber",
                            "usExaminationTypeId",
                        )
                        if key in data
                    }
                    event["request"]["photoCount"] = len(data.get("photos", []))
                    if "requestId" in body:
                        event["request"]["requestId"] = body["requestId"]
                    if path.endswith("parse_dictation"):
                        event["request"] = {
                            key: body[key]
                            for key in (
                                "transcript",
                                "selectedNeuralModelId",
                                "usExaminationTypeId",
                            )
                            if key in body
                        }
                    if path.endswith("/events"):
                        snapshots = [
                            json.loads(line[6:])
                            for line in outgoing.decode().splitlines()
                            if line.startswith("data: ")
                        ]
                        event["streamSnapshots"] = [
                            {
                                key: item[key]
                                for key in ("generationId", "status", "partialReport")
                                if key in item
                            }
                            for item in snapshots
                            if "generationId" in item
                        ]
                        response = next(
                            (
                                item
                                for item in reversed(snapshots)
                                if "generationId" in item
                            ),
                            {},
                        )
                    else:
                        response = json.loads(outgoing) if outgoing else {}
                    event["response"] = {
                        key: response[key]
                        for key in (
                            "generationId",
                            "status",
                            "modelId",
                            "report",
                            "partialReport",
                            "errorCode",
                        )
                        if key in response
                    }
                except (ValueError, TypeError, AttributeError):
                    event["unreadable"] = True
                DIRECTORY.mkdir(exist_ok=True)
                destination = DIRECTORY / f"{time.time_ns()}-{uuid.uuid4().hex}.json"
                destination.write_text(json.dumps(event, ensure_ascii=False))


app = RegressionObserver(backend)
