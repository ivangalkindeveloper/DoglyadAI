"""Validate the exact regression suite and produce a publication only after all checks pass."""

from __future__ import annotations

import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import struct
import xml.etree.ElementTree as ET

import yaml

TEST = Path(__file__).resolve().parents[1]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def cases() -> list[dict]:
    functional = json.loads((TEST / "functional.json").read_text())
    atlas = json.loads((TEST / "catalog.json").read_text())["atlas"]
    return [functional["bootstrap"], *functional["cases"], *atlas]


def suite_hash() -> str:
    values = [
        (str(p.relative_to(TEST)), sha(p))
        for p in sorted(TEST.rglob("*"))
        if p.is_file()
        and not set(p.relative_to(TEST).parts)
        & {"runs", "cache", "secrets", "__pycache__"}
        and p.name not in {"local.json", "manifest.local.json"}
    ]
    return hashlib.sha256(json.dumps(values).encode()).hexdigest()


def flow_commands(path: Path, ancestors: tuple[Path, ...] = ()) -> list[dict | str]:
    """Inspect nested commands and helpers, including paths inside repeat blocks."""
    path = path.resolve()
    if not path.is_relative_to(TEST.resolve()) or not path.is_file():
        raise ValueError(f"Missing subflow or path outside test/: {path}")
    if path in ancestors:
        raise ValueError(f"Recursive subflow: {path}")
    source = path.read_text()
    if any(isinstance(token, yaml.tokens.AliasToken) for token in yaml.scan(source)):
        raise ValueError(
            f"Maestro flows must use explicit values, not YAML aliases: {path}"
        )
    documents = list(yaml.safe_load_all(source))
    if len(documents) != 2 or not isinstance(documents[1], list):
        raise ValueError(f"Invalid flow documents: {path}")

    def walk(commands: list) -> list[dict | str]:
        flattened = []
        for command in commands:
            if not isinstance(command, (str, dict)):
                raise ValueError(f"Invalid command in {path}: {command}")
            flattened.append(command)
            if not isinstance(command, dict):
                continue
            if len(command) != 1:
                raise ValueError(f"Each step needs one command: {path}")
            for name, value in command.items():
                if name == "launchApp" and isinstance(value, dict):
                    if any(
                        not isinstance(argument, str)
                        for argument in value.get("arguments", {}).values()
                    ):
                        raise ValueError(
                            f"iOS launch arguments must be strings for UserDefaults: {path}"
                        )
                if isinstance(value, dict) and value.get("optional"):
                    raise ValueError(
                        f"Optional command could hide a regression: {path}"
                    )
                if name == "runFlow":
                    relative = value if isinstance(value, str) else value.get("file")
                    if relative:
                        flattened.extend(
                            flow_commands(path.parent / relative, (*ancestors, path))
                        )
                if name in {"runFlow", "repeat"} and isinstance(value, dict):
                    flattened.extend(walk(value.get("commands", [])))
        return flattened

    return walk(documents[1])


def validate_suite() -> list[dict]:
    suite = cases()
    ids = [c["id"] for c in suite]
    if not suite or len(set(ids)) != len(ids):
        raise ValueError("Suite is empty or has duplicate case IDs")
    declared = {TEST / c["flow"] for c in suite}
    actual = set((TEST / "modules").glob("*/atlas/*.yaml")) | set(
        (TEST / "modules").glob("*/e2e/*.yaml")
    ) | set((TEST / "components").glob("*/atlas/*.yaml"))
    if declared != actual:
        raise ValueError(f"Unregistered or missing flows: {declared ^ actual}")
    provider_phase = False
    for case in suite:
        if case.get("subscriptionProfile") == "provider":
            if case.get("provider") != "yookassa" or not case.get("paymentPlan"):
                raise ValueError(
                    "Provider cases require an actual YooKassa payment and plan evidence"
                )
            provider_phase = True
        elif provider_phase and case["kind"] != "render":
            raise ValueError(
                "Synthetic subscription fixtures cannot follow real provider cases"
            )
        if case.get("subscriptionProfile", "pro") not in {
            "none",
            "base",
            "pro",
            "expired",
            "exhausted",
            "revoked",
            "provider",
        }:
            raise ValueError(f"Unknown subscription fixture: {case['id']}")
        if any(
            item not in ids[: ids.index(case["id"])]
            for item in case.get("dependsOn", [])
        ):
            raise ValueError(f"Case dependency must execute first: {case['id']}")
        path = TEST / case["flow"]
        header, commands = list(yaml.safe_load_all(path.read_text()))
        if header["name"] != case["id"] or not commands:
            raise ValueError(f"Invalid flow: {path}")
        flattened = flow_commands(path)
        shots = [
            c["takeScreenshot"]
            for c in flattened
            if isinstance(c, dict) and "takeScreenshot" in c
        ]
        if shots != case["screenshots"] or not shots or len(shots) != len(set(shots)):
            raise ValueError(f"Screenshot list differs: {path}")
    return suite


def junit_passed(path: Path, case_id: str) -> bool:
    try:
        root = ET.parse(path).getroot()
        tests = list(root.iter("testcase"))
        return (
            len(tests) == 1
            and tests[0].get("name") == case_id
            and not any(list(root.iter(tag)) for tag in ("failure", "error", "skipped"))
            and all(
                int(node.get(key, "0")) == 0
                for node in root.iter()
                for key in ("failures", "errors", "skipped")
            )
        )
    except (OSError, ET.ParseError, ValueError):
        return False


def dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"Invalid PNG: {path}")
    width, height = struct.unpack(">II", data[16:24])
    if not (0 < width <= 4096 and 0 < height <= 4096):
        raise ValueError(f"PNG dimensions are not supported by Figma: {path}")
    return width, height


def finish(
    run: Path,
    suite: list[dict],
    results: list[dict],
    fingerprint: str,
    config: dict,
    coverage: dict | None = None,
    native_tests: list[str] | None = None,
) -> dict:
    (run / "publication.json").unlink(missing_ok=True)
    expected = [c["id"] for c in suite]
    passed = (
        len(results) == len(suite)
        and [r["id"] for r in results] == expected
        and all(
            r["exitCode"] == 0 and junit_passed(run / r["junit"], r["id"])
            for r in results
        )
        and suite_hash() == fingerprint
    )
    images = []
    native_evidence = None
    if native_tests:
        path = run / "native-checks.json"
        try:
            evidence = json.loads(path.read_text())
            if evidence != {
                "requiredTests": native_tests,
                "results": [{"id": name, "result": "Passed"} for name in native_tests],
            }:
                raise ValueError("Invalid native test evidence")
            native_evidence = {"path": path.name, "sha256": sha(path)}
        except (OSError, ValueError):
            passed = False
    payment_evidence = []
    previous_decline = None
    pending_upgrade = None
    purchased_base = None
    delivery_evidence = []
    backend_evidence = []
    local_evidence = []
    report_evidence = []
    external_evidence = []
    for case, result in zip(suite, results):
        if case.get("externalActions"):
            path = run / "cases" / case["id"] / "external-evidence.json"
            try:
                evidence = json.loads(path.read_text())
                if (
                    evidence.get("status") != "passed"
                    or evidence.get("expected") != case["externalActions"]
                    or evidence.get("adapter") != "external-application"
                    or len(evidence.get("actions", [])) != len(case["externalActions"])
                    or any(
                        item.get("canceled") is not True for item in evidence["actions"]
                    )
                ):
                    raise ValueError("Invalid external application evidence")
                external_evidence.append(
                    dict(
                        caseId=case["id"],
                        path=str(path.relative_to(run)),
                        sha256=sha(path),
                    )
                )
            except (OSError, ValueError):
                passed = False
        if case.get("reportAssertions"):
            path = run / "cases" / case["id"] / "report-evidence.json"
            try:
                evidence = json.loads(path.read_text())
                if (
                    evidence.get("status") != "passed"
                    or evidence.get("expected") != case["reportAssertions"]
                ):
                    raise ValueError("Invalid saved response evidence")
                report_evidence.append(
                    {
                        "caseId": case["id"],
                        "path": str(path.relative_to(run)),
                        "sha256": sha(path),
                    }
                )
            except (OSError, ValueError):
                passed = False
        if case.get("localAssertions"):
            path = run / "cases" / case["id"] / "local-evidence.json"
            try:
                evidence = json.loads(path.read_text())
                if (
                    evidence.get("status") != "passed"
                    or evidence.get("expected") != case["localAssertions"]
                ):
                    raise ValueError("Invalid local persistence evidence")
                local_evidence.append(
                    {
                        "caseId": case["id"],
                        "path": str(path.relative_to(run)),
                        "sha256": sha(path),
                    }
                )
            except (OSError, ValueError):
                passed = False
        if case.get("backendAssertions"):
            path = run / "cases" / case["id"] / "backend-evidence.json"
            try:
                evidence = json.loads(path.read_text())
                count = (
                    0
                    if case["backendAssertions"].get("absent")
                    or case["backendAssertions"].get("dictationText")
                    else len(
                        case["backendAssertions"].get("attemptStatuses", ["completed"])
                    )
                )
                if (
                    evidence.get("status") != "passed"
                    or evidence.get("generationRequests") != count
                    or evidence.get("expected") != case["backendAssertions"]
                ):
                    raise ValueError("Invalid backend request evidence")
                control = case["backendAssertions"].get("worker")
                if control and (
                    evidence.get("worker", {}).get("control") != control
                    or evidence["worker"].get("generationId")
                    != evidence.get("generationId")
                    or not re.fullmatch(
                        r"[a-f0-9]{64}", evidence["worker"].get("sha256", "")
                    )
                ):
                    raise ValueError("Missing worker fault evidence")
                backend_evidence.append(
                    {
                        "caseId": case["id"],
                        "path": str(path.relative_to(run)),
                        "sha256": sha(path),
                    }
                )
            except (OSError, ValueError):
                passed = False
        if case.get("delivery"):
            path = run / "cases" / case["id"] / "delivery-evidence.json"
            try:
                evidence = json.loads(path.read_text())
                if (
                    evidence.get("status") != "passed"
                    or evidence.get("clipboardMatches") is not True
                    or evidence.get("clipboardMode", "full-report")
                    != case["delivery"].get("clipboardMode", "full-report")
                    or evidence.get("recipient") != case["delivery"]["recipient"]
                    or evidence.get("patientName") != case["delivery"]["patientName"]
                    or evidence.get("messagesAccepted") != 1
                    or evidence.get("messagesRejected")
                    != int(case["delivery"]["failNext"])
                    or evidence.get("tls") is not True
                    or evidence.get("authenticated") is not True
                    or len(evidence.get("attachments", []))
                    != case["delivery"]["attachmentCount"]
                ):
                    raise ValueError("Invalid delivery evidence")
                delivery_evidence.append(
                    {
                        "caseId": case["id"],
                        "path": str(path.relative_to(run)),
                        "sha256": sha(path),
                    }
                )
            except (OSError, ValueError):
                passed = False
        if case.get("provider"):
            path = run / "cases" / case["id"] / "payment-evidence.json"
            try:
                evidence = json.loads(path.read_text())
                if (
                    evidence.get("test") is not True
                    or evidence.get("status") != case.get("paymentOutcome", "succeeded")
                    or evidence.get("planId") != case["paymentPlan"]
                    or case.get("paymentOutcome") == "canceled"
                    and evidence.get("providerSubmitted") is not False
                ):
                    raise ValueError("Invalid provider evidence")
                if (
                    case.get("paymentOutcome", "succeeded") == "succeeded"
                    and case["paymentPlan"] == "base_weekly"
                ):
                    purchased_base = evidence
                if case.get("paymentOutcome") == "pending":
                    if (
                        evidence.get("activeTier") != "none"
                        or evidence.get("paymentCount") != 1
                    ):
                        raise ValueError(
                            "Pending payment granted access or duplicated an order"
                        )
                    pending_upgrade = evidence
                if case.get("paymentOutcome") == "active-rejected" and (
                    purchased_base is None
                    or evidence.get("paymentCount") != 1
                    or any(
                        evidence.get(key) != purchased_base.get(key)
                        for key in ["paymentId", "providerPaymentId", "planId"]
                    )
                ):
                    raise ValueError(
                        "Rejected purchase changed the existing Base payment"
                    )
                if case.get("paymentOutcome") == "confirmed" and (
                    pending_upgrade is None
                    or evidence.get("paymentCount") != 1
                    or any(
                        evidence.get(key) != pending_upgrade.get(key)
                        for key in ["paymentId", "providerPaymentId", "planId"]
                    )
                ):
                    raise ValueError(
                        "Confirmation did not complete the exact pending upgrade"
                    )
                if case.get("paymentOutcome") == "declined-retry" and (
                    previous_decline is None
                    or any(
                        evidence.get(key) != previous_decline.get(key)
                        for key in ["paymentId", "providerPaymentId", "planId"]
                    )
                ):
                    raise ValueError(
                        "Retry does not belong to the preceding verified decline"
                    )
                if case.get("paymentOutcome") == "declined":
                    previous_decline = evidence
                if case.get("paymentOutcome") in {"declined", "declined-retry"} and (
                    evidence.get("providerStatus") != "canceled"
                    or evidence.get("providerSubmitted") is not True
                    or evidence.get("reason") != "insufficient_funds"
                    or evidence.get("hasAccess") is not False
                    or evidence.get("paymentCount")
                    != (2 if case.get("paymentOutcome") == "declined-retry" else 1)
                    or case.get("paymentOutcome") == "declined-retry"
                    and evidence.get("retryCanceledWithoutSubmission") is not True
                ):
                    raise ValueError("Invalid provider decline evidence")
                if case.get("providerAction"):
                    action = case["providerAction"]
                    from subscription_evidence import ACTIONS

                    if (
                        action not in ACTIONS
                        or evidence.get("action") != action
                        or any(
                            evidence.get(key) is not True
                            for key in (
                                "paidPeriodUnchanged",
                                "paymentCountUnchanged",
                                "active",
                            )
                        )
                        or evidence.get("autoRenewing") is not False
                    ):
                        raise ValueError("Invalid subscription action evidence")
                    if action in {"create-key", "rotate-key"} and (
                        evidence.get("copiedKeyVerified") is not True
                        or not re.fullmatch(
                            r"[a-f0-9]{64}", evidence.get("keySha256", "")
                        )
                    ):
                        raise ValueError("Missing recovery key proof")
                    if action in {"reject-old-key", "restore-key"} and (
                        evidence.get("cleanClient") is not True
                        or evidence.get("originalOwnerRetained") is not True
                        or evidence.get("credentialsAdded")
                        != int(action == "restore-key")
                        or evidence.get("replacedKeyRejected")
                        != (action == "reject-old-key")
                    ):
                        raise ValueError("Missing recovery identity proof")
                payment_evidence.append(
                    {
                        "caseId": case["id"],
                        "path": str(path.relative_to(run)),
                        "sha256": sha(path),
                    }
                )
            except (OSError, ValueError):
                passed = False
        for screenshot in case["screenshots"]:
            found = list((run / result["artifacts"]).rglob(screenshot + ".png"))
            if len(found) != 1:
                passed = False
                continue
            path = found[0]
            try:
                width, height = dimensions(path)
            except ValueError:
                passed = False
                continue
            target = run / "screenshots" / f"{case['id']}--{screenshot}.png"
            target.parent.mkdir(exist_ok=True)
            shutil.copyfile(path, target)
            named_screen = re.match(r"^(?:\d+-)?([A-Za-z][A-Za-z0-9_]+)-", screenshot)
            screen = (
                named_screen.group(1)
                if named_screen
                else case.get("screen", case["id"])
            )
            images.append(
                {
                    "id": f"{case['id']}--{screenshot}",
                    "caseId": case["id"],
                    "screen": screen,
                    "module": screen,
                    "kind": case["kind"],
                    "displayOrder": case.get("previewOrder", len(images) + 1),
                    "state": case.get("title", screenshot),
                    "platform": "ios",
                    "path": str(target.relative_to(run)),
                    "sha256": sha(target),
                    "width": width,
                    "height": height,
                }
            )
    report = {
        "schemaVersion": 1,
        "runId": run.name,
        "status": "passed" if passed else "failed",
        "executionStatus": "passed" if passed else "failed",
        "passedCases": sum(
            r["exitCode"] == 0 and junit_passed(run / r["junit"], r["id"])
            for r in results
        ),
        "suiteHash": fingerprint,
        "expectedCases": expected,
        "results": results,
        "expectedScreenshots": sum(len(c["screenshots"]) for c in suite),
        "images": images,
        "expectedPaymentCases": [case["id"] for case in suite if case.get("provider")],
        "paymentEvidence": payment_evidence,
        "requiredNativeTests": native_tests or [],
        "nativeEvidence": native_evidence,
        "expectedDeliveryCases": [case["id"] for case in suite if case.get("delivery")],
        "deliveryEvidence": delivery_evidence,
        "expectedBackendCases": [
            case["id"] for case in suite if case.get("backendAssertions")
        ],
        "backendEvidence": backend_evidence,
        "expectedLocalCases": [
            case["id"] for case in suite if case.get("localAssertions")
        ],
        "localEvidence": local_evidence,
        "expectedReportCases": [
            case["id"] for case in suite if case.get("reportAssertions")
        ],
        "reportEvidence": report_evidence,
        "expectedExternalCases": [
            case["id"] for case in suite if case.get("externalActions")
        ],
        "externalEvidence": external_evidence,
        "figmaFileKey": config.get("figmaFileKey", ""),
        "figmaPageName": config.get("figmaPageName", "Doglyad Regression"),
    }
    if coverage is not None:
        report["coverage"] = coverage
        if passed and coverage["missingExecution"]:
            report["status"] = "incomplete"
    (run / "report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    )
    write_index(run, report)
    if passed:
        publication(run)
    return report


def write_index(run: Path, report: dict) -> None:
    """Make failed cases and their original diagnostics accessible without Figma."""
    results = {result["id"]: result for result in report["results"]}
    rows = []
    for identity in report["expectedCases"]:
        result = results.get(identity)
        status = "Не запущен"
        links = ""
        if result is not None:
            folder = Path(result["junit"]).parent
            status = (
                "Пройден"
                if result["exitCode"] == 0
                and junit_passed(run / result["junit"], identity)
                else "Ошибка"
            )
            candidates = {
                "JUnit": result["junit"],
                "Лог Maestro": str(folder / "maestro.log"),
                "Артефакты": result["artifacts"],
            }
            links = " · ".join(
                f'<a href="{html.escape(path, quote=True)}">{title}</a>'
                for title, path in candidates.items()
                if (run / path).exists()
            )
        rows.append(f"<tr><td>{html.escape(identity)}</td><td>{status}</td><td>{links}</td></tr>")
    logs = " · ".join(
        f'<a href="{name}">{name}</a>'
        for name in ("report.json", "failure.txt", "build.log", "environment.log", "services.log")
        if (run / name).is_file()
    )
    failure = run / "failure.txt"
    error = f"<pre>{html.escape(failure.read_text())}</pre>" if failure.is_file() else ""
    cards = "".join(
        f'<figure><figcaption>{html.escape(i["screen"])} · {html.escape(i["state"])}</figcaption><a href="{html.escape(i["path"], quote=True)}"><img loading="lazy" src="{html.escape(i["path"], quote=True)}"></a></figure>'
        for i in report["images"]
    )
    (run / "index.html").write_text(
        f'<!doctype html><meta charset="utf-8"><title>{html.escape(run.name)}</title>'
        '<style>body{font:16px system-ui}main{display:flex;flex-wrap:wrap;gap:24px}figure{width:280px;margin:0}img{width:100%}figcaption{min-height:60px}td{padding:6px 12px;border-bottom:1px solid #ddd}pre{white-space:pre-wrap}</style>'
        f'<h1>{html.escape(run.name)}: {html.escape(report["status"])}</h1>'
        f'<p>{report["passedCases"]}/{len(report["expectedCases"])} кейсов; {len(report["images"])}/{report["expectedScreenshots"]} снимков.</p>'
        f'<p>{logs}</p>{error}<details open><summary>Результаты кейсов</summary>'
        '<table><tr><th>Кейс</th><th>Результат</th><th>Диагностика</th></tr>'
        + "".join(rows) + "</table></details><main>" + cards + "</main>"
    )


def publication(run: Path) -> dict:
    # Keep the execution report immutable, including historical coverage gaps.
    # Earlier successful runs have no publication manifest because coverage used
    # to be an additional gate. Revalidate their evidence before deriving one.
    report = json.loads((run / "report.json").read_text())
    if (
        report.get("executionStatus", report["status"]) != "passed"
        or report["status"] not in {"passed", "incomplete"}
        or not report["expectedCases"]
        or not report["images"]
        or not report.get("suiteHash")
        or report["suiteHash"] == "invalid-run"
        or (run / "failure.txt").exists()
    ):
        raise ValueError("Only a complete successful run can be published")
    data = {
        **report,
        "status": "passed",
        "coverageStatus": (
            "incomplete"
            if report.get("coverage", {}).get("missingExecution")
            else "complete"
        ),
    }
    if [r["id"] for r in data["results"]] != data["expectedCases"]:
        raise ValueError("Incomplete case results")
    if len(set(data["expectedCases"])) != len(data["expectedCases"]):
        raise ValueError("Duplicate case results")
    if len(data["images"]) != data["expectedScreenshots"]:
        raise ValueError("Incomplete screenshot set")
    if len({i["id"] for i in data["images"]}) != len(data["images"]):
        raise ValueError("Duplicate screenshots")
    for result in data["results"]:
        junit = (run / result["junit"]).resolve()
        if (
            not junit.is_relative_to(run.resolve())
            or result["exitCode"] != 0
            or not junit_passed(junit, result["id"])
        ):
            raise ValueError("A test failed or was skipped")
    if data.get("requiredNativeTests"):
        evidence = data.get("nativeEvidence")
        if not evidence:
            raise ValueError("Missing native test evidence")
        path = (run / evidence["path"]).resolve()
        if (
            not path.is_relative_to(run.resolve())
            or not path.is_file()
            or sha(path) != evidence["sha256"]
        ):
            raise ValueError("Native test evidence changed after the run")
    if [item["caseId"] for item in data.get("paymentEvidence", [])] != data.get(
        "expectedPaymentCases", []
    ):
        raise ValueError("Missing provider payment evidence")
    if [item["caseId"] for item in data.get("externalEvidence", [])] != data.get(
        "expectedExternalCases", []
    ):
        raise ValueError("Missing external application evidence")
    for item in data.get("externalEvidence", []):
        path = (run / item["path"]).resolve()
        if (
            not path.is_relative_to(run.resolve())
            or not path.is_file()
            or sha(path) != item["sha256"]
        ):
            raise ValueError("External application evidence changed after the run")
    for item in data.get("paymentEvidence", []):
        path = (run / item["path"]).resolve()
        if (
            not path.is_relative_to(run.resolve())
            or not path.is_file()
            or sha(path) != item["sha256"]
        ):
            raise ValueError("Provider payment evidence changed after the run")
    if [item["caseId"] for item in data.get("deliveryEvidence", [])] != data.get(
        "expectedDeliveryCases", []
    ):
        raise ValueError("Missing SMTP and clipboard evidence")
    for item in data.get("deliveryEvidence", []):
        path = (run / item["path"]).resolve()
        if (
            not path.is_relative_to(run.resolve())
            or not path.is_file()
            or sha(path) != item["sha256"]
        ):
            raise ValueError("Delivery evidence changed after the run")
    if [item["caseId"] for item in data.get("backendEvidence", [])] != data.get(
        "expectedBackendCases", []
    ):
        raise ValueError("Missing backend request evidence")
    for item in data.get("backendEvidence", []):
        path = (run / item["path"]).resolve()
        if (
            not path.is_relative_to(run.resolve())
            or not path.is_file()
            or sha(path) != item["sha256"]
        ):
            raise ValueError("Backend evidence changed after the run")
    if [item["caseId"] for item in data.get("localEvidence", [])] != data.get(
        "expectedLocalCases", []
    ):
        raise ValueError("Missing local persistence evidence")
    for item in data.get("localEvidence", []):
        path = (run / item["path"]).resolve()
        if (
            not path.is_relative_to(run.resolve())
            or not path.is_file()
            or sha(path) != item["sha256"]
        ):
            raise ValueError("Local evidence changed after the run")
    if [item["caseId"] for item in data.get("reportEvidence", [])] != data.get(
        "expectedReportCases", []
    ):
        raise ValueError("Missing saved response evidence")
    for item in data.get("reportEvidence", []):
        path = (run / item["path"]).resolve()
        if (
            not path.is_relative_to(run.resolve())
            or not path.is_file()
            or sha(path) != item["sha256"]
        ):
            raise ValueError("Saved response evidence changed after the run")
    for image in data["images"]:
        path = (run / image["path"]).resolve()
        if not path.is_relative_to(run.resolve()) or sha(path) != image["sha256"]:
            raise ValueError("Screenshot changed after the run")
    manifest = run / "publication.json"
    if manifest.exists():
        previous = json.loads(manifest.read_text())
        # Accept the original manifest shape of older successful runs too.
        if previous not in (report, data):
            raise ValueError("Publication manifest differs from the execution report")
    else:
        temporary = run / "publication.tmp"
        temporary.write_text(json.dumps(data, ensure_ascii=False))
        temporary.replace(manifest)
    return data
