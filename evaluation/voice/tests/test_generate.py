from __future__ import annotations

import hashlib
import json
from collections import Counter
from pathlib import Path

from evaluation.voice.adversarial import generate_cases as generate_adversarial_cases
from evaluation.voice.common import FIELD_IDS, MEASUREMENT_PROFILES, _side_of, load_catalog
from evaluation.voice.generate import jsonl_bytes, make_corpus, write_corpus

REGRESSION_SHA256 = "c044605a4a1a795872d76d29f11baefe815c39763c49db2acd1cc5ebc2078a55"
CONTROL_SHA256 = "8f893aae8411112ecdbc26781605c84d36e356ee29c439254db49c7bcbf1f9e6"


def test_every_type_and_locale_has_separate_cases() -> None:
    type_ids, terms = load_catalog()
    regression, control = make_corpus()
    assert len(type_ids) == 31
    assert len(regression) == 744
    assert len(control) == 248
    assert Counter((case["locale"], case["examinationTypeId"]) for case in regression) == {
        (locale, type_id): 12 for locale in ("en", "ru") for type_id in type_ids
    }
    assert Counter((case["locale"], case["examinationTypeId"]) for case in control) == {
        (locale, type_id): 4 for locale in ("en", "ru") for type_id in type_ids
    }
    assert set(terms) == {"en", "ru"}


def test_cases_have_grounded_sources_and_type_specific_facts() -> None:
    _, terms = load_catalog()
    regression, control = make_corpus()
    cases = regression + control
    assert len({case["id"] for case in cases}) == len(cases)
    assert len({case["spokenText"] for case in cases}) == len(cases)
    assert all(set(case["expectedFields"]) <= set(FIELD_IDS) for case in cases)

    for case in cases:
        expected = case["expectedFields"]
        assert set(case["expectedSourceQuotes"]) == set(expected)
        assert all(quote in case["spokenText"] for quote in case["expectedSourceQuotes"].values())
        if "examinationDescription" not in expected:
            assert case["expectedFacts"] == []
        else:
            measurement = next(fact for fact in case["expectedFacts"] if fact["kind"] == "measurement")
            assert measurement["subject"] in terms[case["locale"]][case["examinationTypeId"]]
            _, minimum, maximum = MEASUREMENT_PROFILES[case["examinationTypeId"]]
            assert minimum <= measurement["value"] <= maximum
            assert any(fact["kind"] == "negation" for fact in case["expectedFacts"])
            for fact in case["expectedFacts"]:
                if fact["kind"] == "side":
                    assert _side_of(measurement["subject"], case["locale"]) == fact["value"]


def test_control_is_disjoint_and_repeatable() -> None:
    regression, control = make_corpus()
    regression_again, control_again = make_corpus()
    assert jsonl_bytes(regression) == jsonl_bytes(regression_again)
    assert jsonl_bytes(control) == jsonl_bytes(control_again)
    assert {case["id"] for case in regression}.isdisjoint(case["id"] for case in control)
    assert {case["scenario"] for case in regression}.isdisjoint(case["scenario"] for case in control)
    assert hashlib.sha256(jsonl_bytes(regression)).hexdigest() == REGRESSION_SHA256
    assert hashlib.sha256(jsonl_bytes(control)).hexdigest() == CONTROL_SHA256


def test_adversarial_cases_are_grounded_and_separate() -> None:
    type_ids, _ = load_catalog()
    cases = generate_adversarial_cases()
    assert len(cases) == 10
    assert {case["scenario"] for case in cases} == {
        "unknown_field",
        "incomplete_date",
        "uncertain_side",
        "similar_terms",
        "prompt_injection",
    }
    assert Counter(case["locale"] for case in cases) == {"en": 5, "ru": 5}
    for case in cases:
        assert case["examinationTypeId"] in type_ids
        assert set(case["expectedSourceQuotes"]) == set(case["expectedFields"])
        assert all(quote in case["spokenText"] for quote in case["expectedSourceQuotes"].values())
        assert set(case["expectedFields"]) <= set(FIELD_IDS)


def test_default_output_reserves_control_cases(tmp_path: Path) -> None:
    output = tmp_path
    manifest = write_corpus(output)
    assert (output / "regression.jsonl").exists()
    assert (output / "adversarial.jsonl").exists()
    assert not (output / "control.jsonl").exists()
    assert manifest["controlReleased"] is False
    assert manifest["regressionSha256"] == hashlib.sha256((output / "regression.jsonl").read_bytes()).hexdigest()
    assert json.loads((output / "manifest.json").read_text(encoding="utf-8")) == manifest

    released = write_corpus(output, release_control=True)
    assert released["controlReleased"] is True
    assert released["controlSha256"] == hashlib.sha256((output / "control.jsonl").read_bytes()).hexdigest()
    assert len((output / "control.jsonl").read_text(encoding="utf-8").splitlines()) == 248
