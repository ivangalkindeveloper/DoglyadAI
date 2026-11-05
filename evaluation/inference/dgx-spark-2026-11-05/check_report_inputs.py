"""Check saved report prompts against the recorded main-backend source revision."""

import hashlib
import json

from analyze import (
    ROOT,
    REPOSITORY,
    ConfigurationLoader,
    LanguageCode,
    MockNeuralModelService,
    ReportGenerationService,
    USExaminationRequest,
)


def text_content(value) -> str:
    if isinstance(value, str):
        return value
    assert all(part["type"] == "text" for part in value)
    return "".join(part["text"] for part in value)


def main() -> None:
    service = ReportGenerationService(
        ConfigurationLoader(REPOSITORY / "backend/main/config/development").load(),
        MockNeuralModelService(),
    )
    rows = []
    for model in ["4b", "15-4b", "27b"]:
        for case in json.loads((ROOT / f"cases-{model}.json").read_text()):
            if case["kind"] in {"vision", "dictation"}:
                continue
            prepared = service.prepare(
                USExaminationRequest.model_validate(case["body"]),
                language_code=LanguageCode(case.get("language", "ru")),
            )
            messages = case["payload"]["messages"]
            rows.append(
                {
                    "model": model,
                    "case": case["id"],
                    "same_system_prompt": text_content(messages[0]["content"])
                    == prepared.system_prompt,
                    "same_user_prompt": text_content(messages[1]["content"])
                    == prepared.prompt,
                    "same_schema": case["schema"]
                    == json.loads(prepared.structured_output),
                    "same_repetition_penalty": case["payload"].get("repetition_penalty")
                    == prepared.repetition_penalty,
                    "system_sha256": hashlib.sha256(
                        prepared.system_prompt.encode()
                    ).hexdigest(),
                    "user_sha256": hashlib.sha256(prepared.prompt.encode()).hexdigest(),
                }
            )
    (ROOT / "report-input-parity.json").write_text(json.dumps(rows, indent=2) + "\n")
    assert all(v for r in rows for k, v in r.items() if k.startswith("same_"))
    print(f"{len(rows)} saved report inputs match current main prompts and schemas")


if __name__ == "__main__":
    main()
