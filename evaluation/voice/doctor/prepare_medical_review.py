from __future__ import annotations

import argparse
import json
import shutil
import tempfile
from pathlib import Path
from typing import Any

from evaluation.voice.datasets.clinical_corpus import content_sha256
from evaluation.voice.common import ROOT
from evaluation.voice.datasets.generate import file_sha256


def prepare_medical_review(
    manifest_path: Path, output: Path, *, locale: str | None = None, is_copy_audio: bool = False
) -> dict[str, Any]:
    """Export gold review before showing recognizer names or model hypotheses."""
    if output.exists():
        raise FileExistsError(output)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    config = ROOT / "backend/main/config/development"
    groups = json.loads((config / "ultrasound_examination_types.json").read_text(encoding="utf-8"))
    titles = json.loads((config / "ru/l10n.json").read_text(encoding="utf-8"))
    type_titles = {item["id"]: titles[item["titleLocaleKey"]] for group in groups for item in group["examinationTypes"]}
    packets: dict[str, dict[str, Any]] = {}
    for case in manifest["cases"]:
        if case.get("mode") == "terminology" or (locale and case["locale"] != locale):
            continue
        payload = {
            key: case.get(key)
            for key in (
                "locale",
                "examinationTypeId",
                "referenceText",
                "expectedFields",
                "clinicalContext",
                "sourceKind",
                "recordingMode",
            )
        }
        key = content_sha256(payload)
        if key not in packets:
            packets[key] = {
                "reviewId": key,
                **payload,
                "examinationTitle": type_titles.get(case["examinationTypeId"], case["examinationTypeId"]),
                "caseIds": [],
                "audio": [],
                "sourceKind": case.get("sourceKind", "legacyUnreviewed"),
                "isMedicalGoldValidated": False,
                "goldReview": {"status": "pending", "reviewerIds": [], "reviewedAt": None, "adjudicationNote": None},
                "reviewQuestions": [
                    "Мог ли врач естественно произнести это во время данного исследования?",
                    "Согласованы ли возраст, пол, анатомия, размеры, единицы и акушерский срок? Если контекста нет, отметить это.",
                    "Совпадает ли эталонная транскрипция с реально слышимой речью? Отметить неразборчивые участки и таймкоды.",
                    "Все ли значения формы следуют из речи? Привести цитаты, сохранить отрицание, сторону, неопределённость и последнее однозначное исправление.",
                    "Какие конкретно поля/фрагменты требуют проверки? Какие сведения отсутствуют и не должны заполняться?",
                ],
                "decisions": {
                    "speechNaturalness": None,
                    "clinicalCoherence": None,
                    "audioReference": None,
                    "goldFields": None,
                    "issues": [],
                    "revisedReferenceText": None,
                    "revisedExpectedFields": None,
                    "fieldEvidence": {},
                    "expectedActions": {},
                },
            }
        packet = packets[key]
        packet["caseIds"].append(case["id"])
        if case.get("audioPath"):
            packet["audio"].append(
                {key: case.get(key) for key in ("id", "variant", "audioPath", "audioSha256", "durationSeconds")}
            )
    report = {
        "schemaVersion": 2,
        "locale": locale,
        "isAudioPortable": is_copy_audio,
        "manifestSha256": file_sha256(manifest_path),
        "sourceCases": len(manifest["cases"]),
        "cases": sum(len(packet["caseIds"]) for packet in packets.values()),
        "excludedTerminologyCases": sum(case.get("mode") == "terminology" for case in manifest["cases"]),
        "reviewItems": len(packets),
        "isClinicallyValidated": False,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".medical-review-", dir=output.parent) as temporary:
        staging = Path(temporary) / "review"
        staging.mkdir()
        for packet in packets.values():
            for audio in packet["audio"]:
                path = Path(audio["audioPath"])
                path = path if path.is_absolute() else ROOT / path
                if is_copy_audio:
                    if file_sha256(path) != audio["audioSha256"]:
                        raise ValueError("Audio differs from frozen review source")
                    relative = Path("audio") / (audio["audioSha256"] + ".wav")
                    (staging / "audio").mkdir(exist_ok=True)
                    if not (staging / relative).exists():
                        shutil.copyfile(path, staging / relative)
                    audio["reviewAudioURL"] = relative.as_posix()
                else:
                    audio["reviewAudioURL"] = path.as_uri()
        (staging / "manifest.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        with (staging / "review.jsonl").open("w", encoding="utf-8") as destination:
            for packet in packets.values():
                destination.write(json.dumps(packet, ensure_ascii=False) + "\n")
        # JSON is data, never executable markup. Escaping '<' prevents a source
        # transcript containing '</script>' from closing this embedded block.
        data = json.dumps({"manifest": report, "items": list(packets.values())}, ensure_ascii=False).replace(
            "<", "\\u003c"
        )
        template = Path(__file__).with_name("index.html").read_text(encoding="utf-8")
        (staging / "review.html").write_text(template.replace("__REVIEW_DATA__", data), encoding="utf-8")
        staging.rename(output)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare a model-blind medical review packet for current recordings")
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--locale", choices=("ru", "en"))
    parser.add_argument(
        "--copy-audio", action="store_true", help="Copy hash-verified WAVs for a portable offline packet"
    )
    args = parser.parse_args()
    print(
        json.dumps(
            prepare_medical_review(args.manifest, args.output, locale=args.locale, is_copy_audio=args.copy_audio),
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
