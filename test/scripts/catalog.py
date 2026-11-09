"""Inventory current code and generate Maestro rendering cases from named application previews."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

import yaml

from preview_fixtures import documents as preview_documents
from legal_previews import generate as legal_previews
from repository_adapters import generate as repository_adapters

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.format_ios import format_swift_source

TEST = ROOT / "test"
MODULES = ROOT / "ios/Doglyad/Application/Module"
APPLICATION = ROOT / "ios/Doglyad/Application/Application/Application"
SHARED_PREVIEWS = ROOT / "ios/Doglyad/Application/Application/View/Preview"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory() -> dict:
    files = {}
    for folder in (
        "ios",
        "backend/main/app",
        "backend/main/config/development",
        "backend/main/mock",
        "backend/main/migrations",
        "backend/inference/app",
        "docs/legal",
    ):
        for path in sorted((ROOT / folder).rglob("*")):
            if (
                (
                    path.suffix
                    in {
                        ".swift",
                        ".py",
                        ".json",
                        ".pbxproj",
                        ".xcscheme",
                        ".xcconfig",
                        ".entitlements",
                        ".strings",
                        ".xcstrings",
                        ".storyboard",
                        ".xib",
                        ".png",
                        ".jpg",
                        ".jpeg",
                        ".pdf",
                        ".svg",
                        ".storekit",
                        ".txt",
                        ".html",
                        ".js",
                        ".css",
                    }
                    or path.name == "Package.resolved"
                )
                and path.is_file()
                and not set(path.parts)
                & {"__pycache__", "xcuserdata", "Firebase", "build"}
            ):
                files[str(path.relative_to(ROOT))] = digest(path)
    for name in (
        "backend/main/Dockerfile",
        "backend/main/requirements.txt",
        "backend/main/alembic.ini",
    ):
        files[name] = digest(ROOT / name)
    modules = [
        {
            "module": "ApplicationSplash",
            "source": str(APPLICATION.relative_to(ROOT)),
            "entries": [
                str((APPLICATION / "ApplicationSplashView.swift").relative_to(ROOT))
            ],
            "states": ["splash"],
            "actions": [],
        }
    ]
    for path in sorted(MODULES.rglob("*Arguments.swift")):
        folder = path.parent
        entries = sorted(
            [*folder.glob("*Screen.swift"), *folder.glob("*BottomSheet.swift")]
        )
        if not entries:
            continue
        models = list((folder / "ViewModel").glob("*ViewModel.swift"))
        modules.append(
            {
                "module": path.stem.removesuffix("Arguments"),
                "source": str(folder.relative_to(ROOT)),
                "entries": [str(p.relative_to(ROOT)) for p in entries],
                "states": [
                    p.stem
                    for p in sorted((folder / "ViewModel/State").glob("*.swift"))
                    if not p.stem.endswith("Protocol")
                ],
                "actions": sorted(
                    {
                        m
                        for p in models
                        for m in re.findall(
                            r"func\s+(on\w+|toggle\w+|setRemarksVisibility)\s*\(",
                            p.read_text(),
                        )
                    }
                ),
            }
        )
    routes = (
        ROOT / "ios/Doglyad/Application/Application/Router/RouteType.swift"
    ).read_text()
    return {
        "files": files,
        "modules": modules,
        "routes": re.findall(r"case\s+(\w+)", routes),
        "backendRoutes": [
            str(p.relative_to(ROOT))
            for p in sorted((ROOT / "backend").glob("*/app/route/**/*.py"))
            if p.name != "__init__.py"
        ],
    }


def extract() -> list[dict]:
    cache = TEST / "cache"
    cache.mkdir(exist_ok=True)
    source = Path(__file__).with_name("extract_previews.swift")
    compiler = Path(
        subprocess.check_output(["xcrun", "--find", "swiftc"], text=True).strip()
    )
    libraries = compiler.parent.parent / "lib/swift/host"
    sdk = subprocess.check_output(
        ["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True
    ).strip()
    version = subprocess.check_output(
        [str(compiler), "--version"], stderr=subprocess.STDOUT
    )
    key = hashlib.sha256(
        source.read_bytes() + str(compiler).encode() + sdk.encode() + version
    ).hexdigest()[:16]
    binary = cache / f"extract-previews-{key}"
    if not binary.exists():
        subprocess.run(
            [
                str(compiler),
                "-sdk",
                sdk,
                "-I",
                str(libraries),
                "-L",
                str(libraries),
                "-Xlinker",
                "-rpath",
                "-Xlinker",
                str(libraries),
                "-module-cache-path",
                str(cache / "swift-modules"),
                str(source),
                "-o",
                str(binary),
            ],
            check=True,
        )
    paths = [str(p.relative_to(ROOT)) for p in sorted(MODULES.rglob("*Preview.swift"))]
    paths.append(
        str((APPLICATION / "Preview/ApplicationSplashPreview.swift").relative_to(ROOT))
    )
    result = subprocess.run(
        [str(binary)],
        input=json.dumps(paths),
        text=True,
        capture_output=True,
        cwd=ROOT,
        check=True,
    )
    return json.loads(result.stdout)


def documents(header: dict, commands: list) -> str:
    return (
        yaml.safe_dump(header, allow_unicode=True, sort_keys=False)
        + "---\n"
        + yaml.safe_dump(commands, allow_unicode=True, sort_keys=False)
    )


def ordered_previews(previews: list[dict], module_order: list[str]) -> list[dict]:
    """Require an explicit user-flow order in each module preview catalog."""
    groups: dict[str, list[int]] = {}
    result = []
    for preview in previews:
        feature = Path(preview["source"]).stem.removesuffix("Preview")
        title = re.fullmatch(r"([0-9]+) (\S.*)", preview["title"])
        if title is None or int(title[1]) < 1:
            raise ValueError(
                f"Preview needs '<number> <name>': {preview['source']} / {preview['title']!r}"
            )
        if feature not in module_order:
            raise ValueError(f"Preview module is absent from moduleOrder: {feature}")
        number = int(title[1])
        groups.setdefault(feature, []).append(number)
        result.append({**preview, "previewOrder": number, "previewName": title[2]})
    for feature, numbers in groups.items():
        if sorted(numbers) != list(range(1, len(numbers) + 1)):
            raise ValueError(
                f"Preview numbers must be unique and consecutive from 1: {feature}"
            )
    return sorted(
        result,
        key=lambda p: (
            module_order.index(Path(p["source"]).stem.removesuffix("Preview")),
            p["previewOrder"],
        ),
    )


def generated() -> dict[str, str]:
    current = inventory()
    functional = json.loads((TEST / "functional.json").read_text())
    cases = []
    full_modules = set()
    swift = [
        "// Generated by test/scripts/catalog.py. Edit the original full-module preview.",
        "#if DEBUG && DOGLYAD_REGRESSION",
        "import Combine",
        "import DoglyadUI",
        "import Router",
        "import SwiftUI",
        "import UIKit",
    ]
    output = {}
    preview_order = functional["moduleOrder"]
    module_previews = [
        p for p in extract() if (ROOT / p["source"]).parent != SHARED_PREVIEWS
    ]
    for preview in ordered_previews(module_previews, preview_order):
        source = Path(preview["source"])
        feature = source.stem.removesuffix("Preview")
        is_full_module = bool(
            re.search(r"\b" + re.escape(feature) + r"PreviewView\s*\(", preview["body"])
        ) or (
            feature == "ApplicationSplash"
            and "ApplicationSplashView(" in preview["body"]
        )
        if not is_full_module:
            continue
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9]*State(?: [A-Za-z][A-Za-z0-9]*)+", preview["previewName"]):
            raise ValueError(f"Full-module preview must use English state and scenario names: {preview['title']}")
        is_scroll_end = ".previewScrollToEnd(" in preview["body"]
        if preview["previewName"].endswith(" ScrollEnd") != is_scroll_end:
            raise ValueError(f"ScrollEnd preview must actually scroll: {preview['title']}")
        full_modules.add(feature)
        # Moving a preview must not change its launch identity.
        suffix = hashlib.sha256(preview["previewName"].encode()).hexdigest()[:10]
        identity = f"atlas-{feature.lower()}-{suffix}"
        number = len(cases) + 1
        screen = f"{preview['previewOrder']:02d}-{feature}-{suffix}"
        flow = f"modules/{feature}/atlas/{identity}.yaml"
        cases.append(
            {
                "id": identity,
                "kind": "render",
                "screen": feature,
                "title": preview["title"],
                "previewOrder": preview["previewOrder"],
                "source": preview["source"],
                "flow": flow,
                "previewScope": "module",
                "screenshots": [screen],
            }
        )
        commands = [
            {"launchApp": {"arguments": {"regressionPreview": identity}}},
            {
                "extendedWaitUntil": {
                    "visible": {"id": f"regression.{identity}"},
                    "timeout": 15000,
                }
            },
        ]
        if feature == "PhotoLibraryPicker":
            # PHPicker loads its system UI after the preview's sheet appears.
            commands.append(
                {"extendedWaitUntil": {"visible": "^Фото$", "timeout": 30000}}
            )
        banner_states = {
            "ShareErrorState",
            "OnBoardingErrorState",
            "SelectTemplateErrorState",
            "ReportDetailErrorState",
            "WorkSettingsErrorState",
            "StorageErrorState",
            "ScanInitializationErrorState",
            "ScanErrorState",
            "TemplateAddErrorState",
            "TemplateEditInitializationErrorState",
            "TemplateEditErrorState",
            "LegalUpdateErrorState",
            "SettingsAIErrorState",
            "TemplateListErrorState",
            "ReadyMadeTemplateListErrorState",
            "WebDocumentErrorState",
            "PaywallCatalogErrorState",
            "PaywallOperationErrorState",
            "SubscriptionRecoveryErrorState",
            "ScanSpeechModelPreparationErrorState",
        }
        if (
            preview["previewName"] in banner_states
            or re.search(r"\bisErrorPresented:\s*true", preview["body"])
            or any(
                re.search(r"\bstate:\s*" + re.escape(state) + r"\s*\(", preview["body"])
                for state in banner_states
            )
            or "scenario: .deliveryFailed" in preview["body"]
            or (
                feature in {"History", "ManageSubscription", "ScanSpeech"}
                and any(
                    f"scenario: .{scenario}" in preview["body"]
                    for scenario in ("failed", "nextPageFailed", "operationFailed")
                )
            )
        ):
            commands.append(
                {
                    "extendedWaitUntil": {
                        "visible": {"id": "message.error"},
                        "timeout": 15000,
                    }
                }
            )
        if feature in {"SelectUSExaminationType", "Menu"}:
            commands.append({"assertNotVisible": {"id": "message.error"}})
        if feature == "SelectUSExaminationType" and re.search(
            r"\bisRecentSectionVisible:\s*false", preview["body"]
        ):
            commands.append({"assertNotVisible": "^Недавние$"})
        if feature == "Paywall":
            if "PaywallCatalogLoadingState" in preview["body"]:
                commands.append({"assertNotVisible": {"id": "paywall.continue"}})
                commands.append({"assertNotVisible": {"id": "paywall.retry"}})
            if "PaywallPurchaseLoadingState" in preview["body"] or "PaywallRestoreLoadingState" in preview["body"]:
                commands.append({"assertVisible": {"id": "paywall.continue", "enabled": True}})
            if "PaywallOperationErrorState" in preview["body"]:
                commands.append({"assertNotVisible": "^Не удалось завершить оплату$"})
        if feature == "Scan" and not is_scroll_end and (
            "state: ScanInitialState(" in re.sub(r"\s+", " ", preview["body"])
            or "state: ScanInitializationErrorState(" in re.sub(r"\s+", " ", preview["body"])
        ):
            for identifier in ("scan.generate", "scan.settings", "scan.type", "scan.patientName", "scan.speech"):
                commands.append({"assertVisible": {"id": identifier, "enabled": True}})
        if feature == "Scan" and not is_scroll_end and "state: ScanGenerationLoadingState(" in re.sub(r"\s+", " ", preview["body"]):
            for identifier in ("scan.settings", "scan.type", "scan.examinationNumber", "scan.patientName"):
                commands.append({"assertVisible": {"id": identifier, "enabled": False}})
            commands.append({"assertVisible": {"id": "scan.generate", "enabled": True}})
        if feature == "ReportReceived":
            if re.search(r"scenario:\s*\.(waitingForFirstToken|firstToken|streamingDescription|streamingConclusion)\b", preview["body"]):
                for identifier in ("reportReceived.openReport", "reportReceived.copy", "reportReceived.sendEmail", "reportReceived.retryGeneration"):
                    commands.append({"assertNotVisible": {"id": identifier}})
            if "scenario: .waitingForFirstToken" in preview["body"]:
                commands.append({"assertVisible": {"id": "reportReceived.generating"}})
            if "scenario: .sendingEmail" in preview["body"]:
                for identifier in ("reportReceived.openReport", "reportReceived.copy"):
                    commands.append({"assertVisible": {"id": identifier, "enabled": False}})
                commands.append({"assertVisible": {"id": "reportReceived.sendEmail", "enabled": True}})
        if feature == "WebDocument" and "WebDocumentSuccessState(" in preview["body"]:
            commands.append({"extendedWaitUntil": {"visible": {"id": "webDocument.loaded"}, "timeout": 30000}})
            commands.append("waitForAnimationToEnd")
        if feature == "WebDocument":
            assertion = (
                "assertVisible"
                if "WebDocumentErrorState(" in preview["body"]
                else "assertNotVisible"
            )
            commands.append({assertion: {"id": "webDocument.retry"}})
        if is_scroll_end:
            commands.append({"extendedWaitUntil": {"visible": {"id": "preview.scrollEnd.ready"}, "timeout": 30000}})
            commands.append("waitForAnimationToEnd")
        elif feature == "ManageSubscription":
            commands.append("waitForAnimationToEnd")
        commands.append({"takeScreenshot": screen})
        output[flow] = documents(
            {"appId": "${APP_ID}", "name": identity, "tags": ["atlas", feature]},
            commands,
        )
        swift += [
            f"struct RegressionCase{number}: View {{",
            "    var body: some View {",
            preview["body"],
            "    }",
            "}",
        ]
    uncovered = {module["module"] for module in current["modules"]} - full_modules
    if uncovered:
        raise ValueError(f"Modules without full-screen previews: {sorted(uncovered)}")
    if not cases or len({case["id"] for case in cases}) != len(cases):
        raise ValueError("Preview extraction returned no cases or duplicate IDs")
    swift += [
        "struct RegressionScreens: View {",
        "    let identity: String",
        "    var body: some View {",
        "        switch identity {",
    ]
    for number, case in enumerate(cases, 1):
        swift += [
            f'        case "{case["id"]}":',
            f"            RegressionCase{number}()",
            "                .accessibilityElement(children: .contain)",
            f'                .accessibilityIdentifier("regression.{case["id"]}")',
        ]
    swift += [
        '        default: Text("Unknown regression preview")',
        "        }",
        "    }",
        "}",
        "#endif",
        "",
    ]
    output["../ios/Doglyad/Regression/RegressionScreens.swift"] = format_swift_source("\n".join(swift))
    output["../ios/Doglyad/Utility/Mock/LegalDocumentPreviewHTML.swift"] = legal_previews()
    output["../ios/Doglyad/Regression/RegressionRepositoryAdapters.swift"] = (
        format_swift_source(repository_adapters())
    )
    # Inventory must describe the generated files that this call will write.
    for name, content in output.items():
        if name.startswith("../ios/"):
            relative = str((TEST / name).resolve().relative_to(ROOT))
            current["files"][relative] = hashlib.sha256(content.encode()).hexdigest()
    output["catalog.json"] = (
        json.dumps(
            {
                "schemaVersion": 1,
                "platforms": ["ios"],
                "inventory": current,
                "atlas": cases,
                "excludedComponentPreviews": [],
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n"
    )
    live = [functional["bootstrap"], *functional["cases"]]
    lines = [
        "# Регресс-кейсы",
        "",
        "Описание сценариев каждого модуля и статус автоматизации: [COVERAGE.md](COVERAGE.md). Ниже перечислены исполняемые flows и отдельные Preview-снимки.",
        "",
        "Список создаёт `python3 test/scripts/catalog.py`. Это перечень проверок, а не результат запуска.",
        "",
        f"Платформа: iOS. Модулей: {len(current['modules'])}. Функциональных кейсов с вводным сценарием: {len(live)}. Кейсов отображения: {len(cases)}.",
        "",
        "## Функциональные сценарии",
        "",
        "Выполняются в указанном порядке на новом стенде. YAML содержит шаги и ожидаемый результат.",
        "",
        "| Кейс | Проверка | Снимков |",
        "|---|---|---|",
    ]
    for case in live:
        title = case.get(
            "title", "Первый запуск: onboarding, согласие, выбор исследования и paywall"
        )
        lines.append(
            f"| [{case['id']}]({case['flow']}) | {title.replace('|', '/')} | {len(case['screenshots'])} |"
        )
    lines += [
        "",
        "## Отображение модулей",
        "",
        "Каждый кейс запускает существующий полноэкранный Preview модуля, проверяет его идентификатор и делает снимок.",
        "Эти кейсы не проверяют переходы в состояния или работу внешних интеграций. Ограничения описаны в [README](README.md#покрытие-и-ограничения).",
        "",
        "| Модуль | Состояние и YAML | Исходник |",
        "|---|---|---|",
    ]
    for case in cases:
        title = case["title"].replace("|", "/")
        lines.append(
            f"| {case['screen']} | [{title}]({case['flow']}) | [Preview](../{case['source']}) |"
        )
    output["CASES.md"] = "\n".join(lines) + "\n"
    output.update(
        {
            f"fixtures/development/{name}": content
            for name, content in preview_documents().items()
        }
    )
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        existing = json.loads((TEST / "catalog.json").read_text())
        old, new = existing["inventory"]["files"], inventory()["files"]
        changed = sorted(p for p in set(old) | set(new) if old.get(p) != new.get(p))
        if changed:
            print(
                "Review changed sources with $test-regress-update before running:\n"
                + "\n".join(changed)
            )
            return 1
        stale = [
            name
            for name, content in generated().items()
            if not (TEST / name).exists() or (TEST / name).read_text() != content
        ]
        if stale:
            print("Generated regression resources are stale:\n" + "\n".join(stale))
            return 1
        print(f"Source inventory is current ({len(existing['atlas'])} render cases).")
        return 0
    values = generated()
    obsolete = [
        *(TEST / "maestro/atlas").glob("atlas-*.yaml"),
        *(TEST / "modules").glob("*/atlas/atlas-*.yaml"),
        *(TEST / "components").glob("*/atlas/atlas-*.yaml"),
    ]
    for old in obsolete:
        if str(old.relative_to(TEST)) not in values:
            old.unlink()
    for name, content in values.items():
        path = TEST / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists() or path.read_text() != content:
            path.write_text(content)
    print(
        f"Generated {sum(name.endswith('.yaml') for name in values)} module rendering flows. Review functional cases separately."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
