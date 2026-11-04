"""Apply the same validator to all models and preserve paired comparisons."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

DIRECTORY = Path(__file__).resolve().parent


def main() -> None:
    spec = importlib.util.spec_from_file_location("schema_analysis", DIRECTORY.parent / "schema-revision/analyze_results.py")
    assert spec is not None and spec.loader is not None
    analyzer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(analyzer)
    combined = {}
    reference = json.loads((DIRECTORY.parent / "schema-revision/summary.json").read_text())
    combined["medgemma-4b"] = {key: reference[key] for key in ("working", "unbounded-grammar")}
    for name in ("medgemma-15-4b", "medgemma-27b"):
        analyzer.DIRECTORY = DIRECTORY / name
        analyzer.main()
        combined[name] = json.loads((analyzer.DIRECTORY / "summary.json").read_text())
        results = {}
        for variant in ("working", "unbounded-grammar"):
            path = analyzer.DIRECTORY / f"{variant}-results.jsonl"
            results[variant] = {
                row["id"]: row
                for row in (json.loads(line) for line in path.read_text().splitlines())
                if row.get("phase") == "quality"
            } if path.exists() else {}
        paired = []
        for identifier in results["working"].keys() & results["unbounded-grammar"].keys():
            left, right = results["working"][identifier], results["unbounded-grammar"][identifier]
            paired.append({
                "id": identifier,
                "prompt_token_ids_equal": left.get("prompt_token_ids") == right.get("prompt_token_ids"),
                "text_equal": left["text"] == right["text"],
                "bounded_finish": left["finish"],
                "unbounded_finish": right["finish"],
            })
        (analyzer.DIRECTORY / "paired-comparison.json").write_text(json.dumps(sorted(paired, key=lambda item: item["id"]), indent=2) + "\n")
    (DIRECTORY / "summary.json").write_text(json.dumps(combined, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
