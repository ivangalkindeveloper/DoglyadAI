from __future__ import annotations

from evaluation.voice.confidence_diagnostic import evaluate, identifier_is_a_distinct_literal, quote_minimum_confidence


def test_quote_confidence_uses_utf16_and_requires_full_unique_coverage() -> None:
    raw = "😀 пол: мужчина"
    quote = "пол: мужчина"
    full = [{"utf16Start": 3, "utf16Length": len(quote), "confidence": 0.995}]
    assert quote_minimum_confidence(raw, quote, full) == 0.995
    assert quote_minimum_confidence(raw, quote, [{**full[0], "utf16Length": 3}]) is None
    assert quote_minimum_confidence(raw + "; " + quote, quote, full) is None


def test_audit_counts_wrong_values_even_without_parser_warnings() -> None:
    quote = "вес: 72 кг"
    report = {
        "results": [
            {
                "id": "case-1",
                "locale": "ru",
                "asr": {
                    "speechAnalyzer/hints=true": {
                        "status": "ok",
                        "rawText": quote,
                        "confidenceSpans": [{"utf16Start": 0, "utf16Length": len(quote), "confidence": 1.0}],
                    }
                },
                "recognizedTextParse": {
                    "speechAnalyzer": {
                        "status": "ok",
                        "source": "labeledDictation",
                        "fields": {"patientWeightKG": 72},
                        "sourceQuotes": {"patientWeightKG": quote},
                        "warnings": {"patientWeightKG": []},
                    }
                },
            }
        ],
    }
    summary = {
        "scoredCases": [
            {
                "id": "case-1",
                "locale": "ru",
                "speechAnalyzer": {"matches": {"patientWeightKG": False}},
            }
        ]
    }
    audit = evaluate(report, summary)
    assert audit["policy"]["automatic"] == 1
    assert audit["policy"]["wrong"] == 1
    assert audit["thresholds"]["0.99"]["automatic"] == 1
    assert audit["thresholds"]["0.99"]["wrong"] == 1


def test_identifier_uses_value_confidence_and_requires_boundaries() -> None:
    quote = "Examination number 048"
    assert identifier_is_a_distinct_literal(quote, "048")
    assert not identifier_is_a_distinct_literal("Examination number 1048", "048")
    report = {
        "results": [
            {
                "id": "case-1",
                "locale": "en",
                "asr": {
                    "speechAnalyzer/hints=true": {
                        "status": "ok",
                        "rawText": quote,
                        "confidenceSpans": [
                            {"utf16Start": 0, "utf16Length": len(quote) - 3, "confidence": 0.3},
                            {"utf16Start": len(quote) - 3, "utf16Length": 3, "confidence": 0.9},
                        ],
                    }
                },
                "recognizedTextParse": {
                    "speechAnalyzer": {
                        "status": "ok",
                        "source": "labeledDictation",
                        "fields": {"examinationNumber": "048"},
                        "sourceQuotes": {"examinationNumber": quote},
                        "warnings": {"examinationNumber": []},
                    }
                },
            }
        ],
    }
    summary = {
        "scoredCases": [
            {
                "id": "case-1",
                "locale": "en",
                "speechAnalyzer": {"matches": {"examinationNumber": True}},
            }
        ]
    }
    audit = evaluate(report, summary)
    assert audit["policy"]["automatic"] == 1
    assert audit["policy"]["correct"] == 1
    assert audit["thresholds"]["0.5"]["automatic"] == 0
