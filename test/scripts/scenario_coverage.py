"""Validate module scenario specifications separately from executed Maestro coverage."""

from __future__ import annotations
import argparse
import json
import yaml
from catalog import TEST, inventory
from native_checks import REQUIRED_TESTS


def review() -> dict:
    current = inventory()
    modules = {item["module"]: item for item in current["modules"]}
    functional = json.loads((TEST / "functional.json").read_text())
    flows = {
        item["id"]: item for item in [functional["bootstrap"], *functional["cases"]]
    }
    specs = sorted((TEST / "modules").glob("*/cases.yaml"))
    seen_modules, seen_cases = set(), set()
    rows, missing_execution = [], []
    for path in specs:
        document = yaml.safe_load(path.read_text())
        module = document["module"]
        if (
            module not in modules
            or module in seen_modules
            or path.parent.name != module
        ):
            raise ValueError(f"Unknown or duplicated module: {module}")
        seen_modules.add(module)
        if document["source"] != modules[module]["source"]:
            raise ValueError(f"Stale source for {module}")
        covered = set()
        if not document["cases"]:
            raise ValueError(f"No scenarios for {module}")
        for case in document["cases"]:
            identity = case["id"]
            if identity in seen_cases or not identity.startswith(module + "."):
                raise ValueError(f"Duplicate or wrong case ID: {identity}")
            seen_cases.add(identity)
            if (
                not case.get("title")
                or not case.get("preconditions")
                or not case.get("steps")
            ):
                raise ValueError(f"Case lacks preparation or steps: {identity}")
            if any(
                not step.get("action") or not step.get("expect")
                for step in case["steps"]
            ):
                raise ValueError(f"Each step needs an expected result: {identity}")
            covered.update(case["covers"])
            automation = case["automation"]
            if automation["kind"] not in {"maestro", "mixed", "partial", "manual"}:
                raise ValueError(f"Invalid automation status: {identity}")
            if automation["kind"] != "manual" and not automation.get("flows"):
                raise ValueError(f"No linked flows: {identity}")
            for flow_id in automation.get("flows", []):
                if flow_id not in flows:
                    raise ValueError(f"Missing automation {flow_id} for {identity}")
            native = automation.get("nativeTests", [])
            if any(name not in REQUIRED_TESTS for name in native) or (
                automation["kind"] == "mixed" and not native
            ):
                raise ValueError(f"Missing mandatory native checks for {identity}")
            if automation["kind"] not in {"maestro", "mixed"}:
                if not automation.get("requires"):
                    raise ValueError(f"Explain missing automation: {identity}")
                missing_execution.append(
                    {"id": identity, "requires": automation["requires"]}
                )
        unknown = covered - set(modules[module]["actions"])
        missing = set(modules[module]["actions"]) - covered
        if unknown or missing:
            raise ValueError(
                f"{module}: unknown callbacks {sorted(unknown)}, unspecified callbacks {sorted(missing)}"
            )
        counts = {
            kind: sum(c["automation"]["kind"] == kind for c in document["cases"])
            for kind in ["maestro", "mixed", "partial", "manual"]
        }
        rows.append({"module": module, "cases": len(document["cases"]), **counts})
    if seen_modules != set(modules):
        raise ValueError(
            f"Modules without specifications: {sorted(set(modules) - seen_modules)}"
        )
    order = functional["moduleOrder"]
    if len(order) != len(set(order)) or set(order) != set(modules):
        raise ValueError("moduleOrder must contain every module exactly once")
    rows.sort(key=lambda row: order.index(row["module"]))
    return {
        "schemaVersion": 1,
        "modules": rows,
        "specifiedCases": len(seen_cases),
        "automatedFlows": len(flows),
        "missingExecution": missing_execution,
    }


def documents(data: dict) -> dict[str, str]:
    lines = [
        "# Карта покрытия модулей",
        "",
        "Это полнота описания сценариев по найденным callback-методам, а не процент покрытия кода или доказательство прохождения тестов.",
        "",
        "`maestro` — весь сценарий связан с flows; `mixed` — flows и обязательные проверки XCTest; `partial` — автоматизирована часть; `manual` — нужна ручная проверка или подготовка стенда.",
        "",
        f"Описанных сценариев: {data['specifiedCases']}. Функциональных Maestro-кейсов: {data['automatedFlows']}. Preview учитываются отдельно и не закрывают функциональные пробелы.",
        "",
        "| Модуль | Сценариев | Maestro | Maestro + XCTest | Частично | Вручную / нужен стенд |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    output = {}
    partial = sum(row["partial"] for row in data["modules"])
    manual = sum(row["manual"] for row in data["modules"])
    gaps = [
        "# Сценарии с неполной автоматизацией",
        "",
        f"Всего {partial + manual}: {partial} автоматизированы частично, {manual} требуют ручной проверки или подготовки стенда.",
        "",
        "Число в названии коллекции Figma относится к этим описанным модульным сценариям. Исполняемые Maestro-кейсы и Preview считаются отдельно: несколько flows могут проверять части одного сценария. Успешный Preview подтверждает отображение состояния, но не выполнение действий пользователя.",
        "",
        "Ниже сохранены требования из `automation.requires` каждого `cases.yaml`. Пройденные части частичных сценариев не закрывают оставшиеся проверки.",
        "",
    ]

    def cell(value: str) -> str:
        return value.replace("|", "\\|").replace("\n", " ")

    for row in data["modules"]:
        name = row["module"]
        lines.append(
            f"| [{name}](modules/{name}/README.md) | {row['cases']} | {row['maestro']} | {row['mixed']} | {row['partial']} | {row['manual']} |"
        )
        spec = yaml.safe_load((TEST / "modules" / name / "cases.yaml").read_text())
        text = [
            f"# {name}",
            "",
            f"Исходники: [{spec['source']}](../../../{spec['source']}).",
            "",
            "Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.",
            "",
            "| ID | Сценарий | Автоматизация |",
            "|---|---|---|",
        ]
        for case in spec["cases"]:
            text.append(
                f"| `{case['id']}` | {case['title']} | {case['automation']['kind']} |"
            )
        remaining = [
            case
            for case in spec["cases"]
            if case["automation"]["kind"] not in {"maestro", "mixed"}
        ]
        if remaining:
            gaps += [
                f"## {name}",
                "",
                f"Полные шаги: [cases.yaml](modules/{name}/cases.yaml).",
                "",
                "| Сценарий | Статус | Что осталось проверить или подготовить |",
                "|---|---|---|",
            ]
            for case in remaining:
                automation = case["automation"]
                status = (
                    "Частично"
                    if automation["kind"] == "partial"
                    else "Вручную / нужен стенд"
                )
                requirements = "<br>".join(
                    cell(item) for item in automation["requires"]
                )
                gaps.append(
                    f"| `{case['id']}`<br>{cell(case['title'])} | {status} | {requirements} |"
                )
            gaps.append("")
        text += [
            "",
            "Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.",
            "",
        ]
        output[f"modules/{name}/README.md"] = "\n".join(text)
    lines += [
        "",
        "Полный список сценариев с причинами: [COVERAGE-GAPS.md](COVERAGE-GAPS.md).",
        "",
        "## Публикация",
        "",
        "Сценарии `manual` и `partial` остаются пробелами покрытия и не считаются пройденными. Они показаны в отчёте и названии коллекции Figma. Публикация разрешена только после успеха всех зарегистрированных исполняемых кейсов, проверки обязательных снимков и очистки окружения. Скриншоты Preview не заменяют отсутствующие функциональные проверки.",
        "",
        "Для подключения сценария полностью реализуйте его шаги в Maestro/тестовом стенде, укажите точные flow IDs и только затем смените automation.kind на maestro. Не меняйте статус ради зелёного отчёта.",
        "",
    ]
    output["COVERAGE.md"] = "\n".join(lines)
    output["COVERAGE-GAPS.md"] = "\n".join(gaps)
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = review()
    for name, content in documents(data).items():
        path = TEST / name
        if args.check:
            if not path.exists() or path.read_text() != content:
                raise ValueError(f"Stale coverage document: {name}")
        else:
            path.write_text(content)
    print(
        f"Specifications: {data['specifiedCases']} cases / {len(data['modules'])} modules; functional flows: {data['automatedFlows']}; not fully automated: {len(data['missingExecution'])}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
