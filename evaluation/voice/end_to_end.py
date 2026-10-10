from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import wave
from datetime import date
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.prepare_ios import FIXTURE_DIR

OUTPUT = ROOT / "build/voice-eval/device-end-to-end"
FIXTURE = ROOT / "evaluation/voice/fixtures/free_speech_final_holdout.json"


def speech_chunks(text: str) -> list[str]:
    chunks: list[str] = []
    for sentence in re.split(r"(?<=[.!?])\s+", text):
        current = ""
        for word in sentence.split():
            candidate = f"{current} {word}".strip()
            if len(candidate) > 150 and current:
                chunks.append(current)
                current = word
            else:
                current = candidate
        if current:
            chunks.append(current)
    if " ".join(chunks) != " ".join(text.split()):
        raise ValueError("Splitting the speech changed its content")
    return chunks


def join_audio(parts: list[Path], destination: Path) -> None:
    buffers: list[bytes] = []
    sample_rate: int | None = None
    for part in parts:
        with wave.open(str(part), "rb") as audio:
            if audio.getnchannels() != 1 or audio.getsampwidth() != 2 or not audio.getnframes():
                raise ValueError(f"Invalid speech segment: {part}")
            if sample_rate is not None and sample_rate != audio.getframerate():
                raise ValueError("Speech segments have different sample rates")
            sample_rate = audio.getframerate()
            buffers.append(audio.readframes(audio.getnframes()))
    if sample_rate is None:
        raise ValueError("No speech segments")
    pause = b"\x00\x00" * round(sample_rate * 0.18)
    with wave.open(str(destination), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(sample_rate)
        audio.writeframes(pause.join(buffers))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def formatted_text(fields: dict[str, Any], locale: str, reordered: bool) -> str:
    birthday = date.fromisoformat(fields["patientDateOfBirth"])
    if locale == "ru":
        months = (
            "января",
            "февраля",
            "марта",
            "апреля",
            "мая",
            "июня",
            "июля",
            "августа",
            "сентября",
            "октября",
            "ноября",
            "декабря",
        )
        parts = [
            f"Номер исследования: {fields['examinationNumber']}.",
            f"Пациент: {fields['patientName']}.",
            f"Пол: {'мужчина' if fields['patientGender'] == 'male' else 'женщина'}.",
            f"Дата рождения: {birthday.day} {months[birthday.month - 1]} {birthday.year} года.",
            f"Рост: {fields['patientHeightCM']} сантиметров.",
            f"Вес: {fields['patientWeightKG']} килограммов.",
            f"Жалобы: {fields['patientComplaints']}",
            f"Описание исследования: {fields['examinationDescription']}",
        ]
    else:
        parts = [
            f"Examination number: {fields['examinationNumber']}.",
            f"Patient: {fields['patientName']}.",
            f"Gender: {fields['patientGender']}.",
            f"Date of birth: {birthday.strftime('%B')} {birthday.day}, {birthday.year}.",
            f"Height: {fields['patientHeightCM']} centimeters.",
            f"Weight: {fields['patientWeightKG']} kilograms.",
            f"Complaints: {fields['patientComplaints']}",
            f"Examination description: {fields['examinationDescription']}",
        ]
    order = (7, 5, 1, 6, 3, 0, 4, 2) if reordered else range(8)
    return " ".join(parts[index] for index in order)


def prepare() -> None:
    source = json.loads(FIXTURE.read_text(encoding="utf-8"))
    types = {
        "ru": [
            "abdominalCavity",
            "kidneysAdrenalGlandsAndRetroperitonealSpace",
            "thyroidGland",
            "echocardiography",
            "abdominalCavity",
            "veinsOfTheLowerExtremities",
            "joints",
            "softTissues",
            "salivaryGlands",
            "mammaryGlands",
            "abdominalCavity",
            "pelvicOrgans",
            "brachiocephalicVessels",
            "softTissues",
            "abdominalCavity",
            "abdominalCavity",
            "abdominalCavity",
            "pleuralRegion",
            "abdominalCavity",
            "abdominalCavity",
        ],
        "en": [
            "joints",
            "thyroidGland",
            "kidneysAdrenalGlandsAndRetroperitonealSpace",
            "abdominalVessels",
            "pleuralRegion",
            "joints",
            "kidneysAdrenalGlandsAndRetroperitonealSpace",
            "lymphNodes",
            "pelvicOrgans",
            "joints",
            "salivaryGlands",
            "scrotum",
            "brachiocephalicVessels",
            "abdominalCavity",
            "abdominalCavity",
            "abdominalCavity",
            "abdominalCavity",
            "pregnancySecondTrimester",
            "abdominalCavity",
            "abdominalCavity",
        ],
    }
    rows: list[dict[str, Any]] = []
    for case in source:
        index = int(case["id"].rsplit("-", 1)[1]) - 1
        rows.append({**case, "pack": "free-speech", "examinationTypeId": types[case["locale"]][index]})
        if case["category"] == "complete":
            for pack, reordered in (("guided-format", False), ("reordered-format", True)):
                rows.append(
                    {
                        **rows[-1],
                        "id": f"e2e-{pack}-{case['locale']}-{index + 1:02d}",
                        "pack": pack,
                        "inputText": formatted_text(case["expectedFields"], case["locale"], reordered),
                    }
                )
    # Interleave packs and languages so a small pilot covers every route and input style.
    rows.sort(key=lambda row: (int(row["id"].rsplit("-", 1)[1]), row["pack"], row["locale"]))
    synthesize_rows(rows, output=OUTPUT, fixture=FIXTURE, manifest_name="end-to-end")


def synthesize_rows(rows: list[dict[str, Any]], *, output: Path, fixture: Path, manifest_name: str) -> None:
    if (output / "cases.json").exists():
        raise ValueError("This corpus is already frozen; use a new output directory")
    output.mkdir(parents=True, exist_ok=True)
    FIXTURE_DIR.mkdir(parents=True, exist_ok=True)
    jobs = []
    for row in rows:
        row["audioFile"] = f"e2e-{row['id']}.wav"
        row["speechChunks"] = speech_chunks(row.get("spokenText", row["inputText"]))
        for index, chunk in enumerate(row["speechChunks"]):
            jobs.append(
                {
                    "id": f"{row['id']}/{index}",
                    "locale": row["locale"],
                    "spokenText": chunk,
                    "voiceIdentifier": "com.apple.voice.compact.ru-RU.Milena"
                    if row["locale"] == "ru"
                    else "com.apple.eloquence.en-US.Flo",
                    "outputPath": str(output / "segments" / f"{row['id']}-{index}.wav"),
                }
            )
    jobs_path = output / "jobs.json"
    jobs_path.write_text(json.dumps(jobs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    binary = output / "audio-synth"
    subprocess.run(["swiftc", str(ROOT / "evaluation/voice/AudioSynthAlt/main.swift"), "-o", str(binary)], check=True)
    results_path = output / "synthesis.jsonl"
    subprocess.run([str(binary), str(jobs_path), str(results_path)], check=True)
    synthesis = [json.loads(line) for line in results_path.read_text().splitlines()]
    if len(synthesis) != len(jobs) or any(item["status"] != "ok" for item in synthesis):
        raise ValueError("Not all audio files were synthesized; inspect synthesis.jsonl")
    for row in rows:
        path = output / row["audioFile"]
        parts = [output / "segments" / f"{row['id']}-{index}.wav" for index in range(len(row["speechChunks"]))]
        join_audio(parts, path)
        row["audioSha256"] = sha256(path)
        shutil.copyfile(path, FIXTURE_DIR / row["audioFile"])
    manifest = {"schemaVersion": 2, "fixtureSha256": sha256(fixture), "cases": rows}
    content = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    (output / "cases.json").write_text(content, encoding="utf-8")
    (FIXTURE_DIR / f"{manifest_name}.json").write_text(content, encoding="utf-8")
    print(f"Prepared {len(rows)} audio files / {sum(len(row['expectedFields']) for row in rows)} expected fields")


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare synthetic audio for the production voice pipeline on iPhone")
    parser.parse_args()
    prepare()


if __name__ == "__main__":
    main()
