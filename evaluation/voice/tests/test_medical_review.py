from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.common import ROOT
from evaluation.voice.doctor.prepare_medical_review import prepare_medical_review


def test_portable_review_is_bound_to_audio_and_does_not_execute_transcript(tmp_path: Path) -> None:
    audio = tmp_path / "source.wav"
    audio.write_bytes(b"test-only audio content")
    case = {
        "id": "a",
        "locale": "ru",
        "examinationTypeId": "kidneys",
        "referenceText": '</script><script>alert("unexpected")</script>',
        "expectedFields": {},
        "audioPath": str(audio),
        "audioSha256": file_sha256(audio),
    }
    source = tmp_path / "manifest.json"
    source.write_text(json.dumps({"cases": [case, {**case, "id": "en", "locale": "en"}]}))
    output = tmp_path / "review"
    report = prepare_medical_review(source, output, locale="ru", is_copy_audio=True)
    assert report["reviewItems"] == report["cases"] == 1
    html = (output / "review.html").read_text()
    embedded = re.search(r'<script id="review-data" type="application/json">(.*?)</script>', html).group(1)
    item = json.loads(embedded)["items"][0]
    assert item["referenceText"] == case["referenceText"]
    assert case["referenceText"] not in html
    clip = item["audio"][0]
    assert file_sha256(output / clip["reviewAudioURL"]) == case["audioSha256"]
    assert not report["isClinicallyValidated"]
    with pytest.raises(FileExistsError):
        prepare_medical_review(source, output)
    if shutil.which("node"):
        subprocess.run(
            ["node", str(Path(__file__).with_name("medical_review_ui.cjs")), str(output / "review.html")],
            check=True,
            capture_output=True,
            text=True,
        )
    audio.write_bytes(b"changed audio")
    with pytest.raises(ValueError, match="differs"):
        prepare_medical_review(source, tmp_path / "invalid", is_copy_audio=True)
    assert not (tmp_path / "invalid").exists()


def test_direct_template_opening_shows_packet_selection_instead_of_a_broken_form() -> None:
    page = ROOT / "evaluation/voice/doctor/index.html"
    html = page.read_text()
    assert '<div id="review-workspace" hidden>' in html
    assert '<section id="choose-packet">' in html
    links = re.findall(r'class="packet-link" href="([^"]+)"', html)
    assert {(page.parent / link).resolve().relative_to(ROOT).as_posix() for link in links} == {
        "build/voice-eval/medical-review-current-ru/review.html",
        "build/voice-eval/medical-review-pilot-ru/review.html",
    }
    if shutil.which("node"):
        subprocess.run(
            ["node", str(Path(__file__).with_name("medical_review_ui.cjs")), str(page), "launcher"],
            check=True,
            capture_output=True,
            text=True,
        )
