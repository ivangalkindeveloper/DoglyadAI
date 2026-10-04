from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.generate import file_sha256


def export_raw_replay(source: Path, output: Path) -> dict[str, Any]:
    report = json.loads(source.read_text(encoding="utf-8"))
    if "speechanalyzer" not in report.get("recognizer", "").lower():
        raise ValueError("Raw lexicon replay requires a SpeechAnalyzer report")
    rows = []
    for row in report["results"]:
        copied = dict(row)
        if copied["status"] == "ok":
            raw = copied.get("rawText")
            if not isinstance(raw, str) or not raw:
                raise ValueError(f"Missing raw SpeechAnalyzer text for {copied['caseId']}")
            copied["correctedText"] = raw
            if "rawWER" in copied:
                copied["correctedWER"] = copied["rawWER"]
        rows.append(copied)
    derived = {
        **report,
        "recognizer": "SpeechAnalyzer rawText for lexicon replay",
        "rawReplayOfSha256": file_sha256(source),
        "results": rows,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(derived, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return derived


def main() -> None:
    parser = argparse.ArgumentParser(description="Replay SpeechAnalyzer raw text through the current Swift lexicon")
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    report = export_raw_replay(args.source, args.output)
    print(f"Prepared {len(report['results'])} raw SpeechAnalyzer transcripts")


if __name__ == "__main__":
    main()
