from __future__ import annotations

from typing import Any

from evaluation.voice.common import FIELD_IDS, make_source, render_case

SCENARIOS = (
    "findings_first",
    "sparse_side_and_words",
    "revised_measurement",
    "unresolved_conflict",
)


def generate_cases(locale: str, type_id: str, terms: dict[str, dict[str, list[str]]]) -> list[dict[str, Any]]:
    """Control cases use a separate seed and different layouts from regression."""
    cases: list[dict[str, Any]] = []
    for index, scenario in enumerate(SCENARIOS):
        values, spoken, facts = make_source(
            "control",
            locale,
            type_id,
            index,
            terms,
            side="left" if index in (1, 3) else "right" if index == 0 else None,
            correction=index == 2,
            words=index == 1,
        )
        included: tuple[str, ...] = FIELD_IDS
        order: tuple[str, ...] = (
            "examinationDescription",
            "examinationNumber",
            "patientName",
            "patientGender",
            "patientDateOfBirth",
            "patientComplaints",
            "patientHeightCM",
            "patientWeightKG",
        )
        review_reasons: tuple[str, ...] = ()

        if index == 1:
            included = ("examinationNumber", "patientName", "examinationDescription")
            order = ("patientName", "examinationDescription", "examinationNumber")
        elif index == 2:
            included = ("patientComplaints", "examinationDescription", "patientHeightCM", "patientWeightKG")
            order = ("patientComplaints", "patientHeightCM", "examinationDescription", "patientWeightKG")
            height = values["patientHeightCM"] / 100
            spoken["patientHeightCM"] = f"{height:.2f} {'meters' if locale == 'en' else 'метра'}"
            review_reasons = ("self_correction",)
        elif index == 3:
            other_number = facts[0]["value"] + 2
            spoken["examinationDescription"] += (
                f" Or {other_number} {facts[0]['unit']}, I am unsure."
                if locale == "en"
                else f" Или {other_number} {facts[0]['unit']}, не уверен."
            )
            values.pop("examinationDescription")
            review_reasons = ("conflicting_facts",)

        cases.append(
            render_case(
                split="control",
                locale=locale,
                type_id=type_id,
                index=index,
                scenario=scenario,
                values=values,
                spoken=spoken,
                facts=facts,
                included=included,
                order=order,
                separator="\n",
                review_reasons=review_reasons,
            )
        )
    return cases
