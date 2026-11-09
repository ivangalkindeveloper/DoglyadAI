"""Run the complete iOS regression in an isolated local environment."""

from __future__ import annotations

import argparse
import base64
from datetime import datetime, timezone
import fcntl
import json
import os
import plistlib
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid

from dotenv import load_dotenv

from artifacts import TEST, finish, suite_hash, validate_suite
from catalog import ROOT, inventory
from scenario_coverage import review
from payment_environment import payment_environment, verify_test_merchant
from payment_evidence import owner_ids, verify_payment
from report_evidence import snapshot as report_snapshot, verify as verify_report
from subscription_evidence import SubscriptionEvidence, redact_recovery_diagnostics
from external_evidence import snapshot as external_snapshot, verify as verify_external
from mail_environment import prepare_mail_tls
from delivery_evidence import mail_status, verify_delivery
from backend_evidence import verify_requests
from worker_evidence import arm_worker, verify_worker
from local_evidence import snapshot as local_snapshot, verify_local
from native_checks import REQUIRED_TESTS, TEST_FILTERS, collect as collect_native_checks

DEFAULT_BACKEND_BUILD_TIMEOUT_SECONDS = 3600
PROGRESS_INTERVAL_SECONDS = 15


def configuration() -> dict:
    load_dotenv(TEST / "secrets/.env", override=False, interpolate=False)
    path = TEST / "secrets/config.local.json"
    if not path.exists():
        raise ValueError(
            "Copy test/config.example.json to test/secrets/config.local.json and set Firebase paths. See test/README.md."
        )
    config = json.loads(path.read_text())
    build_timeout = config.get(
        "backendBuildTimeoutSeconds", DEFAULT_BACKEND_BUILD_TIMEOUT_SECONDS
    )
    if type(build_timeout) is not int or build_timeout <= 0:
        raise ValueError(
            "backendBuildTimeoutSeconds must be a positive integer in seconds"
        )
    config["backendBuildTimeoutSeconds"] = build_timeout
    credentials = (ROOT / config["firebaseCredentials"]).resolve()
    if not credentials.is_file():
        raise ValueError(
            "firebaseCredentials does not point to an existing service account file"
        )
    config["firebaseCredentials"] = str(credentials)
    if (
        config.get("appId") != "com.medical.doglyad.local"
        or config.get("scheme") != "Doglyad-Debug-Local"
    ):
        raise ValueError("Regression uses only the local app ID and local scheme")
    if (
        not os.environ.get("REGRESSION_APP_CHECK_DEBUG_TOKEN")
        and not _is_local_app_check_configured()
    ):
        raise ValueError(
            "Set APP_CHECK_DEBUG_TOKEN in ios/Config/Config.Local.xcconfig, "
            "or override it with REGRESSION_APP_CHECK_DEBUG_TOKEN in test/secrets/.env "
            "or the process environment. Register the token in Firebase development App Check."
        )
    return config


def _is_local_app_check_configured() -> bool:
    """Resolve xcconfig includes/macros with Xcode without publishing build settings."""
    try:
        result = subprocess.run(
            [
                "xcodebuild",
                "-project",
                str(ROOT / "ios/Doglyad.xcodeproj"),
                "-scheme",
                "Doglyad-Debug-Local",
                "-showBuildSettings",
                "-json",
                "-derivedDataPath",
                str(TEST / "cache/DerivedData"),
                "-disableAutomaticPackageResolution",
                "-skipPackageUpdates",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
            timeout=60,
        )
        if result.returncode:
            return False
        targets = json.loads(result.stdout)
        for target in targets:
            if target.get("target") != "Doglyad":
                continue
            settings = target["buildSettings"]
            token = settings.get("APP_CHECK_DEBUG_TOKEN", "").strip()
            return (
                settings.get("CONFIGURATION") == "Debug-Local"
                and settings.get("PRODUCT_BUNDLE_IDENTIFIER")
                == "com.medical.doglyad.local"
                and bool(token)
                and "$(" not in token
                and "${" not in token
            )
    except (OSError, subprocess.TimeoutExpired, ValueError, KeyError, TypeError):
        # Captured output and exception arguments can contain the token.
        return False
    return False


def maestro_executable() -> str:
    installed = shutil.which("maestro")
    if installed:
        return str(Path(installed).resolve())
    standard = Path.home() / ".maestro/bin/maestro"
    if standard.is_file() and os.access(standard, os.X_OK):
        return str(standard)
    raise ValueError(
        "Maestro CLI was not found in PATH or ~/.maestro/bin/maestro. "
        "Install Maestro CLI or add its bin directory to PATH; see test/README.md"
    )


def maestro_driver_port(first_port: int) -> int:
    """Avoid the macOS ephemeral ports reused while XCTest starts."""
    for port in range(max(22087, first_port), 32768):
        with socket.socket() as candidate:
            try:
                candidate.bind(("0.0.0.0", port))
            except OSError:
                continue
            return port
    raise RuntimeError("No free Maestro driver port in 22087–32767")


def doctor(config: dict) -> None:
    for command in ("docker", "xcrun", "xcodebuild", "openssl"):
        if not shutil.which(command):
            raise ValueError(f"Missing {command}; see test/README.md")
    maestro_executable()
    context = json.loads(
        subprocess.check_output(["docker", "context", "inspect"], text=True)
    )
    docker_host = (
        os.environ.get("DOCKER_HOST") or context[0]["Endpoints"]["docker"]["Host"]
    )
    if not docker_host.startswith("unix://"):
        raise ValueError("Regression requires a local Docker Unix socket")
    subprocess.run(
        ["docker", "info", "--format", "{{.ServerVersion}}"],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    with socket.socket() as sock:
        try:
            sock.bind(("127.0.0.1", 18765))
        except OSError as error:
            raise ValueError(
                "Port 18765 is occupied; regression will not stop an existing service"
            ) from error
    expected = json.loads((TEST / "catalog.json").read_text())["inventory"]["files"]
    if inventory()["files"] != expected:
        raise ValueError(
            "Source catalog is stale. Use $test-regress-update before running."
        )
    suite = validate_suite()
    if any(case.get("provider") == "yookassa" for case in suite):
        verify_test_merchant(payment_environment(ROOT, config))


def run_command(
    command: list[str],
    log: Path,
    *,
    env: dict | None = None,
    timeout: int = 1200,
    input_text: str | None = None,
    progress: str | None = None,
) -> int:
    started = time.monotonic()
    stopped = threading.Event()

    def report_progress() -> None:
        while not stopped.wait(PROGRESS_INTERVAL_SECONDS):
            elapsed = int(time.monotonic() - started)
            status = log.stat()
            last_output = max(0, int(time.time() - status.st_mtime))
            print(
                f"[{progress}] {elapsed}s elapsed; log: {status.st_size} bytes, last update {last_output}s ago.",
                flush=True,
            )

    with log.open("a") as output:
        reporter = None
        if progress:
            print(f"[{progress}] timeout: {timeout}s; log: {log}", flush=True)
            reporter = threading.Thread(target=report_progress, daemon=True)
            reporter.start()
        try:
            result = subprocess.run(
                command,
                cwd=ROOT,
                env=env,
                input=input_text,
                text=True,
                stdout=output,
                stderr=subprocess.STDOUT,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired:
            # TimeoutExpired formats argv, which can include the App Check token.
            raise RuntimeError(
                f"Command timed out after {timeout}s; inspect {log}"
            ) from None
        finally:
            stopped.set()
            if reporter:
                reporter.join()
    if progress:
        print(
            f"[{progress}] finished in {int(time.monotonic() - started)}s; exit code: {result.returncode}.",
            flush=True,
        )
    return result.returncode


def required(command: list[str], log: Path, **kwargs) -> None:
    if run_command(command, log, **kwargs):
        raise RuntimeError(f"Command failed; inspect {log.relative_to(ROOT)}")


def start_environment(
    compose: list[str], run: Path, env: dict, build_timeout: int
) -> None:
    required(
        [*compose, "build"],
        run / "environment.log",
        env=env,
        timeout=build_timeout,
        progress="Building backend images",
    )
    required(
        [*compose, "up", "--no-build", "-d"],
        run / "environment.log",
        env=env,
        progress="Starting database, migrations, API and report worker",
    )


def wait_backend(timeout: float = 120) -> None:
    # No unauthenticated health route or App Check bypass is introduced.
    # An auth rejection confirms HTTP startup; bootstrap then checks real authenticated reads.
    deadline = time.monotonic() + timeout
    next_progress = time.monotonic() + PROGRESS_INTERVAL_SECONDS
    last_probe = "no HTTP response"
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(
                "http://127.0.0.1:18765/v1/application_config", timeout=3
            ) as response:
                raise RuntimeError(
                    f"Unauthenticated configuration unexpectedly returned {response.status}"
                )
        except urllib.error.HTTPError as error:
            error.close()
            if error.code in (401, 403):
                print(
                    "Backend is ready; unauthenticated access is rejected.", flush=True
                )
                return
            last_probe = f"HTTP {error.code}"
        except (urllib.error.URLError, ConnectionError, TimeoutError) as error:
            # Docker can publish the port before Uvicorn accepts HTTP requests.
            # RemoteDisconnected inherits ConnectionResetError/ConnectionError.
            last_probe = type(error).__name__
        now = time.monotonic()
        if now >= next_progress:
            print(f"Waiting for backend; last probe: {last_probe}.", flush=True)
            next_progress = now + PROGRESS_INTERVAL_SECONDS
        time.sleep(1)
    raise RuntimeError(
        f"Backend did not become ready within {timeout:g}s; last probe: {last_probe}. "
        "Inspect this run's services.log."
    )


def cleanup(device: str | None, compose: list[str], run: Path, env: dict) -> bool:
    """Attempt every cleanup action even if an earlier action fails or times out."""
    actions = []
    if device:
        actions += [
            (["xcrun", "simctl", "shutdown", device], "device.log", 60, False),
            (["xcrun", "simctl", "delete", device], "device.log", 60, True),
        ]
    actions += [
        ([*compose, "logs", "--no-color"], "services.log", 60, False),
        (
            [*compose, "down", "--volumes", "--remove-orphans"],
            "environment.log",
            120,
            True,
        ),
    ]
    clean = True
    for command, log, timeout, mandatory in actions:
        try:
            code = run_command(command, run / log, env=env, timeout=timeout)
            if mandatory and code:
                clean = False
        except (RuntimeError, OSError, subprocess.SubprocessError, KeyboardInterrupt):
            # Do not format the command: another operation can contain a secret.
            with (run / "cleanup.log").open("a") as output:
                output.write(f"Cleanup action failed: {log}; required={mandatory}\n")
            if mandatory:
                clean = False
    return clean


def execute(config: dict, publish: bool) -> int:
    if publish and not config.get("figmaFileKey"):
        raise ValueError(
            "Set figmaFileKey in test/secrets/config.local.json before --publish"
        )
    suite = validate_suite()
    coverage = review()
    maestro = maestro_executable()
    fingerprint = suite_hash()
    source_fingerprint = inventory()["files"]
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run = ROOT / "build/regression/runs" / run_id
    run.mkdir(parents=True)
    backend_evidence = run / "backend-evidence"
    backend_evidence.mkdir(mode=0o777)
    backend_evidence.chmod(0o777)
    compose_project = "doglyad-regression-" + uuid.uuid4().hex[:12]
    compose = [
        "docker",
        "compose",
        "--project-name",
        compose_project,
        "-f",
        str(TEST / "compose.yaml"),
    ]
    env = dict(
        os.environ,
        REGRESSION_FIREBASE_CREDENTIALS=config["firebaseCredentials"],
        REGRESSION_ENCRYPTION_KEY=base64.urlsafe_b64encode(os.urandom(32)).decode(),
        REGRESSION_BACKEND_EVIDENCE_DIR=str(backend_evidence.resolve()),
    )
    if any(case.get("provider") == "yookassa" for case in suite):
        env.update(payment_environment(ROOT, config))
        verify_test_merchant(env)
    device = None
    subscription_evidence = SubscriptionEvidence(compose_project, env)
    results = []
    error_message = None
    clean = True
    current_profile = None
    mail_tls = TEST / "secrets" / ("smtp-" + compose_project)
    try:
        env["REGRESSION_SMTP_TLS_DIR"] = prepare_mail_tls(mail_tls)
        print(
            f"Run: {run.relative_to(ROOT)}. Starting isolated PostgreSQL, API and report worker.",
            flush=True,
        )
        start_environment(compose, run, env, config["backendBuildTimeoutSeconds"])
        print("Waiting for backend readiness.", flush=True)
        wait_backend()
        if json.loads((backend_evidence / "observer-ready.json").read_text()) != {
            "observerVersion": 1
        }:
            raise RuntimeError("Backend request observer did not start")
        runtimes = json.loads(
            subprocess.check_output(
                ["xcrun", "simctl", "list", "runtimes", "-j"], text=True
            )
        )["runtimes"]
        available = [
            r
            for r in runtimes
            if r.get("isAvailable")
            and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
        ]
        if not available:
            raise ValueError("Install an iOS simulator runtime in Xcode")
        runtime = (
            config.get("simulatorRuntime")
            or sorted(
                available, key=lambda r: tuple(map(int, r["version"].split(".")))
            )[-1]["identifier"]
        )
        device = subprocess.check_output(
            [
                "xcrun",
                "simctl",
                "create",
                "Doglyad Regression " + run_id,
                config["simulatorDeviceType"],
                runtime,
            ],
            text=True,
        ).strip()
        required(["xcrun", "simctl", "boot", device], run / "device.log")
        required(
            ["xcrun", "simctl", "bootstatus", device, "-b"],
            run / "device.log",
            timeout=240,
            progress="Booting iOS Simulator",
        )
        # The token is never included in the report, YAML, screenshots, or command logs.
        if token := env.get("REGRESSION_APP_CHECK_DEBUG_TOKEN"):
            required(
                [
                    "xcrun",
                    "simctl",
                    "spawn",
                    device,
                    "launchctl",
                    "setenv",
                    "AppCheckDebugToken",
                    token,
                ],
                run / "device.log",
            )
        required(
            [
                "xcrun",
                "simctl",
                "spawn",
                device,
                "defaults",
                "write",
                "NSGlobalDomain",
                "AppleLanguages",
                "-array",
                "ru",
            ],
            run / "device.log",
        )
        required(
            [
                "xcrun",
                "simctl",
                "spawn",
                device,
                "defaults",
                "write",
                "NSGlobalDomain",
                "AppleLocale",
                "ru_RU",
            ],
            run / "device.log",
        )
        required(
            [
                "xcrun",
                "simctl",
                "status_bar",
                device,
                "override",
                "--time",
                "9:41",
                "--batteryState",
                "charged",
                "--batteryLevel",
                "100",
            ],
            run / "device.log",
        )
        derived = TEST / "cache/DerivedData"
        print(
            "Building the regression app and checking native photo gestures.",
            flush=True,
        )
        required(
            [
                "xcodebuild",
                "test",
                "-disableAutomaticPackageResolution",
                "-skipPackageUpdates",
                "-project",
                "ios/Doglyad.xcodeproj",
                "-scheme",
                config["scheme"],
                "-destination",
                f"platform=iOS Simulator,id={device}",
                "-derivedDataPath",
                str(derived),
                "-parallel-testing-enabled",
                "NO",
                "-resultBundlePath",
                str(run / "native-tests.xcresult"),
                *["-only-testing:" + name for name in TEST_FILTERS],
                "OTHER_SWIFT_FLAGS=$(inherited) -DDOGLYAD_REGRESSION",
                "BASE_URL=http://127.0.0.1:18765",
            ],
            run / "build.log",
            timeout=1800,
            progress="Building regression iOS app and checking gestures",
        )
        collect_native_checks(run / "native-tests.xcresult", run / "native-checks.json")
        app = derived / "Build/Products/Debug-Local-iphonesimulator/Doglyad.app"
        required(["xcrun", "simctl", "install", device, str(app)], run / "device.log")
        data_container = Path(
            subprocess.check_output(
                [
                    "xcrun",
                    "simctl",
                    "get_app_container",
                    device,
                    config["appId"],
                    "data",
                ],
                text=True,
            ).strip()
        )
        gallery = run / "fixtures" / "gallery"
        gallery.mkdir(parents=True)
        gallery_files = []
        for number in range(1, 8):
            name = f"{number:02d}-camera.png"
            source = data_container / "Documents" / "RegressionGallery" / name
            if not source.is_file():
                raise RuntimeError(
                    "Native checks did not export the simulator camera images"
                )
            destination = gallery / name
            shutil.copyfile(source, destination)
            gallery_files.append(str(destination))
        # Import individually: simctl's multi-file import does not preserve input order.
        for file in gallery_files:
            required(["xcrun", "simctl", "addmedia", device, file], run / "device.log")
        for number, case in enumerate(suite, 1):
            if (
                number > 1
                and case["kind"] != "render"
                and case.get("subscriptionProfile") != "provider"
            ):
                profile = case.get("subscriptionProfile", "pro")
                if profile not in {
                    "none",
                    "base",
                    "pro",
                    "expired",
                    "exhausted",
                    "revoked",
                }:
                    raise ValueError(f"Unknown subscription profile: {profile}")
                if profile != current_profile:
                    required(
                        [
                            *compose,
                            "exec",
                            "-T",
                            "database",
                            "psql",
                            "-v",
                            "ON_ERROR_STOP=1",
                            "-v",
                            "regression_daily_allowance="
                            + str(
                                json.loads(
                                    (
                                        ROOT
                                        / "backend/main/config/development/application.json"
                                    ).read_text()
                                )["entitlements"]["pro"]["requestCountPerDay"]
                            ),
                            "-U",
                            "regression",
                            "-d",
                            "regression",
                        ],
                        run / "seed.log",
                        env=env,
                        input_text=(
                            TEST / "fixtures/subscriptions" / f"{profile}.sql"
                        ).read_text(),
                    )
                    current_profile = profile
            folder = run / "cases" / case["id"]
            folder.mkdir(parents=True)
            print(
                f"[{number}/{len(suite)}] {case.get('title', case['id'])}", flush=True
            )
            result = {
                "id": case["id"],
                "exitCode": -1,
                "junit": str((folder / "junit.xml").relative_to(run)),
                "artifacts": str((folder / "artifacts").relative_to(run)),
            }
            results.append(result)
            local_before = (
                local_snapshot(device, config["appId"])
                if case.get("localAssertions")
                else None
            )
            report_before = (
                report_snapshot(
                    device, config["appId"], case["reportAssertions"]["patientName"]
                )
                if case.get("reportAssertions")
                else None
            )
            external_before = (
                external_snapshot(device, config["appId"])
                if case.get("externalActions")
                else None
            )
            payment_owners_before = (
                owner_ids(compose_project) if case.get("provider") else None
            )
            if case.get("providerAction"):
                subscription_evidence.before(case["providerAction"], device)
            worker_control = case.get("backendAssertions", {}).get("worker")
            worker_before = (
                arm_worker(backend_evidence / "worker", worker_control)
                if worker_control
                else None
            )
            requests_before = set(backend_evidence.glob("*.json"))
            mail_before = None
            if case.get("delivery"):
                mail_before = mail_status(compose, env)
                required(
                    ["xcrun", "simctl", "pbcopy", device],
                    folder / "clipboard.log",
                    input_text="regression-not-copied",
                )
                if case["delivery"]["failNext"]:
                    required(
                        [
                            *compose,
                            "exec",
                            "-T",
                            "mail",
                            "python",
                            "receiver.py",
                            "fail-next",
                        ],
                        folder / "mail.log",
                        env=env,
                    )
            result["exitCode"] = run_command(
                [
                    maestro,
                    "--device",
                    device,
                    "test",
                    "--driver-host-port",
                    str(maestro_driver_port(22087 + number)),
                    "--format",
                    "junit",
                    "--output",
                    str(folder / "junit.xml"),
                    "--test-output-dir",
                    str(folder / "artifacts"),
                    "-e",
                    "APP_ID=" + config["appId"],
                    "-e",
                    "APP_VERSION="
                    + plistlib.loads((app / "Info.plist").read_bytes())[
                        "CFBundleShortVersionString"
                    ],
                    str(TEST / case["flow"]),
                ],
                folder / "maestro.log",
                timeout=case.get("timeoutSeconds", 600),
                progress=f"Maestro: {case['id']}",
            )
            if result["exitCode"]:
                raise RuntimeError(f"Case failed: {case['id']}")
            if case.get("reportAssertions"):
                try:
                    evidence = verify_report(
                        report_before,
                        report_snapshot(
                            device,
                            config["appId"],
                            case["reportAssertions"]["patientName"],
                        ),
                        case["reportAssertions"],
                        subprocess.check_output(
                            ["xcrun", "simctl", "pbpaste", device], text=True
                        ),
                    )
                    (folder / "report-evidence.json").write_text(
                        json.dumps(evidence, indent=2) + "\n"
                    )
                except (ValueError, OSError, KeyError, subprocess.SubprocessError):
                    result["exitCode"] = 1
                    raise RuntimeError(
                        f"Saved response evidence failed: {case['id']}"
                    ) from None
            if case.get("externalActions"):
                try:
                    evidence = verify_external(
                        external_before,
                        external_snapshot(device, config["appId"]),
                        case["externalActions"],
                        delivered=mail_status(compose, env)["messages"]
                        if any(
                            item["kind"] == "report" for item in case["externalActions"]
                        )
                        else None,
                    )
                    (folder / "external-evidence.json").write_text(
                        json.dumps(evidence, indent=2) + "\n"
                    )
                except (ValueError, OSError, subprocess.SubprocessError):
                    result["exitCode"] = 1
                    raise RuntimeError(
                        f"External application evidence failed: {case['id']}"
                    ) from None
            if case.get("localAssertions"):
                try:
                    evidence = verify_local(
                        local_before,
                        local_snapshot(device, config["appId"]),
                        case["localAssertions"],
                    )
                    (folder / "local-evidence.json").write_text(
                        json.dumps(evidence, indent=2) + "\n"
                    )
                except (ValueError, OSError, subprocess.SubprocessError):
                    result["exitCode"] = 1
                    raise RuntimeError(
                        f"Local persistence evidence failed: {case['id']}"
                    ) from None
            if case.get("backendAssertions"):
                try:
                    observed = sorted(
                        set(backend_evidence.glob("*.json")) - requests_before
                    )
                    evidence = verify_requests(
                        [json.loads(path.read_text()) for path in observed],
                        case["backendAssertions"],
                        compose_project,
                    )
                    if worker_control:
                        evidence["worker"] = verify_worker(
                            backend_evidence / "worker",
                            worker_before,
                            worker_control,
                            evidence["generationId"],
                        )
                    (folder / "backend-evidence.json").write_text(
                        json.dumps(evidence, indent=2) + "\n"
                    )
                except (ValueError, OSError, KeyError, subprocess.SubprocessError):
                    result["exitCode"] = 1
                    raise RuntimeError(
                        f"Backend request evidence failed: {case['id']}"
                    ) from None
            if case.get("delivery"):
                try:
                    clipboard = subprocess.check_output(
                        ["xcrun", "simctl", "pbpaste", device], text=True
                    )
                    evidence = verify_delivery(
                        mail_before,
                        mail_status(compose, env),
                        clipboard,
                        case["delivery"],
                    )
                    (folder / "delivery-evidence.json").write_text(
                        json.dumps(evidence, indent=2) + "\n"
                    )
                except (ValueError, OSError, subprocess.SubprocessError):
                    result["exitCode"] = 1
                    raise RuntimeError(
                        f"SMTP or clipboard evidence failed: {case['id']}"
                    ) from None
            if case.get("paymentPlan"):
                try:
                    evidence = (
                        subscription_evidence.after(case["providerAction"], device)
                        if case.get("providerAction")
                        else verify_payment(
                            compose_project,
                            case["paymentPlan"],
                            env,
                            payment_owners_before,
                            case.get("paymentOutcome", "succeeded"),
                        )
                    )
                    (folder / "payment-evidence.json").write_text(
                        json.dumps(evidence, indent=2) + "\n"
                    )
                except (ValueError, OSError, subprocess.SubprocessError):
                    result["exitCode"] = 1
                    raise RuntimeError(
                        f"Provider evidence failed: {case['id']}"
                    ) from None
        if source_fingerprint != inventory()["files"]:
            raise RuntimeError("Application sources changed during this run")
    except (
        RuntimeError,
        ValueError,
        OSError,
        subprocess.SubprocessError,
        KeyboardInterrupt,
    ) as error:
        error_message = (
            str(error) if not isinstance(error, KeyboardInterrupt) else "Interrupted"
        )
        print(error_message, file=sys.stderr)
    finally:
        try:
            try:
                subscription_evidence.clear(device)
            finally:
                redact_recovery_diagnostics(run / "cases")
        except (OSError, subprocess.SubprocessError):
            error_message = (
                error_message
                or "Could not clear recovery diagnostics or the regression clipboard"
            )
        clean = cleanup(device, compose, run, env)
        if clean and mail_tls.exists():
            shutil.rmtree(mail_tls)
        if error_message or not clean:
            (run / "failure.txt").write_text(
                error_message or "Environment cleanup failed"
            )
        # A failure after the last UI case must also prohibit publication.
        effective = fingerprint if not error_message and clean else "invalid-run"
        report = finish(
            run, suite, results, effective, config, coverage, REQUIRED_TESTS
        )
    print(f"Report: {run / 'index.html'}", flush=True)
    if report["executionStatus"] != "passed":
        return 1
    if report["status"] == "incomplete":
        print(
            f"All {len(suite)} registered cases and expected screenshots passed. "
            f"Coverage is incomplete: {len(coverage['missingExecution'])} module "
            "scenarios still require automation; these gaps remain in the report.",
            flush=True,
        )
    if publish:
        from figma_bridge import serve

        if not serve(run):
            print(
                "Tests passed; Figma has not acknowledged the update. Reuse this successful run with make regression-publish RUN=...",
                file=sys.stderr,
            )
            return 2
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "doctor", "run"))
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "validate":
            print(f"Validated {len(validate_suite())} cases.")
            return 0
        config = configuration()
        doctor(config)
        if args.command == "doctor":
            print("Regression prerequisites are ready.")
            return 0
        (TEST / "cache").mkdir(exist_ok=True)
        with (TEST / "cache/run.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return execute(config, args.publish)
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
