"""Capture every registered Russian Preview and optionally update only Figma Preview."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import fcntl
import json
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

from artifacts import TEST, dimensions, sha, suite_hash
from catalog import ROOT, inventory
from preview_artifacts import preview_publication
from regression import maestro_driver_port, maestro_executable, required, run_command


def save(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def runtime(config: dict) -> str:
    if config.get("simulatorRuntime"):
        return config["simulatorRuntime"]
    values = json.loads(
        subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "--json"])
    )["runtimes"]
    ios = [r for r in values if r.get("isAvailable") and ".iOS-" in r["identifier"]]
    if not ios:
        raise ValueError("Install an iOS Simulator runtime")
    return max(ios, key=lambda r: tuple(map(int, r["version"].split("."))))["identifier"]


def render(run: Path, config: dict, catalog: dict, workers: int) -> dict:
    cases = catalog["atlas"]
    functional = json.loads((TEST / "functional.json").read_text())
    source_hash = inventory()["files"]
    if source_hash != catalog["inventory"]["files"]:
        raise ValueError("Source catalog is stale; refresh regression cases first")
    fingerprint = suite_hash()
    save(run / "catalog.json", catalog)
    devices = []
    report = {
        "scope": "previews", "status": "failed", "functionalTestsRun": False,
        "runId": run.name, "suiteHash": fingerprint,
        "catalogSha256": sha(run / "catalog.json"),
        "figmaFileKey": config.get("figmaFileKey", ""),
        "figmaPageName": config.get("figmaPageName", "Doglyad Regression"),
        "expectedCases": [case["id"] for case in cases],
        "expectedScreenshots": sum(len(case["screenshots"]) for case in cases),
        "results": [], "images": [], "junitHashes": {}, "batchExitCodes": {},
        "cleanupStatus": "failed",
        "coverageStatus": "not-evaluated",
        "coverage": {"modules": [{"module": name} for name in (
            functional["moduleOrder"] + functional["sharedPreviewOrder"]
        )]},
    }
    try:
        for index in range(min(workers, len(cases))):
            device = subprocess.check_output(
                ["xcrun", "simctl", "create", f"Doglyad Preview {run.name} {index + 1}",
                 config["simulatorDeviceType"], runtime(config)], text=True,
            ).strip()
            devices.append(device)
        print(f"Preview capture: {len(cases)} cases, {len(devices)} isolated simulators. {run}", flush=True)
        required(
            ["xcodebuild", "build", "-project", "ios/Doglyad.xcodeproj", "-scheme", "Doglyad-Debug-Local",
             "-destination", f"platform=iOS Simulator,id={devices[0]}",
             "-derivedDataPath", "test/cache/DerivedData", "-disableAutomaticPackageResolution", "-skipPackageUpdates",
             "OTHER_SWIFT_FLAGS=$(inherited) -DDOGLYAD_REGRESSION", "BASE_URL=http://127.0.0.1:18765"],
            run / "build.log", timeout=1800, progress="Building Preview app",
        )
        app = TEST / "cache/DerivedData/Build/Products/Debug-Local-iphonesimulator/Doglyad.app"
        batches = [cases[index::len(devices)] for index in range(len(devices))]
        ports = [maestro_driver_port(22500 + index * 100) for index in range(len(devices))]

        def capture(index: int) -> tuple[str, int]:
            device = devices[index]
            folder = run / f"batch-{index + 1}"
            flows = folder / "flows"
            flows.mkdir(parents=True)
            for position, case in enumerate(batches[index]):
                shutil.copyfile(TEST / case["flow"], flows / f"{position:03d}-{case['id']}.yaml")
            log = folder / "device.log"
            required(["xcrun", "simctl", "boot", device], log)
            required(["xcrun", "simctl", "bootstatus", device, "-b"], log, timeout=180)
            required(["xcrun", "simctl", "status_bar", device, "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100"], log)
            required(["xcrun", "simctl", "ui", device, "appearance", "light"], log)
            required(["xcrun", "simctl", "install", device, str(app)], log)
            junit = folder / "junit.xml"
            code = run_command(
                [maestro_executable(), "--device", device, "test", "--driver-host-port", str(ports[index]),
                 "--format", "junit", "--output", str(junit), "--test-output-dir", str(folder / "artifacts"),
                 "-e", "APP_ID=com.medical.doglyad.local", str(flows)],
                folder / "maestro.log", timeout=3600, progress=f"Preview batch {index + 1}/{len(devices)}",
            )
            return str(junit.relative_to(run)), code

        with ThreadPoolExecutor(max_workers=len(devices)) as executor:
            outcomes = list(executor.map(capture, range(len(devices))))
        results = {}
        images = {}
        for index, (relative, code) in enumerate(outcomes):
            report["batchExitCodes"][relative] = code
            path = run / relative
            report["junitHashes"][relative] = sha(path)
            tests = list(ET.parse(path).getroot().iter("testcase"))
            by_name = {test.get("name"): test for test in tests}
            if len(by_name) != len(tests):
                raise ValueError("Duplicate Preview JUnit cases")
            for case in batches[index]:
                test = by_name.get(case["id"])
                passed = test is not None and not any(list(test.iter(tag)) for tag in ("failure", "error", "skipped"))
                results[case["id"]] = {"id": case["id"], "exitCode": 0 if passed else 1, "junit": relative}
                for shot in case["screenshots"]:
                    paths = list((run / f"batch-{index + 1}" / "artifacts").rglob(shot + ".png"))
                    if len(paths) != 1:
                        raise ValueError(f"Missing or repeated Preview screenshot: {shot}")
                    image = paths[0]
                    width, height = dimensions(image)
                    images[(case["id"], shot)] = {
                        "id": case["id"] + "--" + shot, "caseId": case["id"], "shot": shot,
                        "kind": "render", "module": case["screen"], "screen": case["screen"],
                        "state": case["title"], "displayOrder": case["previewOrder"], "locale": "ru",
                        "path": str(image.relative_to(run)), "sha256": sha(image), "width": width, "height": height,
                    }
        report["results"] = [results[case["id"]] for case in cases]
        report["images"] = [images[(case["id"], shot)] for case in cases for shot in case["screenshots"]]
        if any(code != 0 for _, code in outcomes) or any(result["exitCode"] for result in report["results"]):
            raise ValueError("Some Preview cases failed")
        if suite_hash() != fingerprint or inventory()["files"] != source_hash:
            raise ValueError("Sources changed during Preview capture")
        report["status"] = "passed"
    except Exception as error:
        report["error"] = str(error)
        raise
    finally:
        clean = True
        for device in devices:
            log = run / "cleanup.log"
            run_command(["xcrun", "simctl", "shutdown", device], log, timeout=60)
            if run_command(["xcrun", "simctl", "delete", device], log, timeout=60):
                clean = False
        report["cleanupStatus"] = "passed" if clean else "failed"
        if not clean:
            report["status"] = "failed"
        save(run / "preview-report.json", report)
    return preview_publication(run)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publish", action="store_true")
    parser.add_argument("--workers", type=int, choices=(1, 2), default=2)
    args = parser.parse_args()
    config = json.loads((TEST / "secrets/config.local.json").read_text())
    if config.get("appId") != "com.medical.doglyad.local" or config.get("scheme") != "Doglyad-Debug-Local":
        raise ValueError("Preview capture uses the local regression app only")
    if args.publish and not config.get("figmaFileKey"):
        raise ValueError("Configure the Figma file key before publishing Preview")
    (TEST / "cache").mkdir(exist_ok=True)
    with (TEST / "cache/run.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        run = ROOT / "build/previews/runs" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        run.mkdir(parents=True, exist_ok=False)
        catalog = json.loads((TEST / "catalog.json").read_text())
        render(run, config, catalog, args.workers)
    print(f"All {len(catalog['atlas'])} Preview passed. Artifacts: {run}", flush=True)
    if args.publish:
        from figma_bridge import serve
        if not serve(run, previews=True):
            raise RuntimeError(f"Figma transfer timed out; reuse {run} with --previews")


if __name__ == "__main__":
    main()
