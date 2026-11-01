from __future__ import annotations

import asyncio
import json
from pathlib import Path

import httpx
import pytest

from evaluation.voice.runners import server_matrix_parse


def test_server_matrix_deduplicates_only_identical_inputs_and_preserves_all_paths(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source = tmp_path / "inputs.jsonl"
    cases = [
        {
            "id": "whisperKit/a",
            "matrixCaseId": "a",
            "recognizer": "whisperKit",
            "locale": "en",
            "examinationTypeId": "kidneys",
            "text": "Left kidney",
        },
        {
            "id": "canary/a",
            "matrixCaseId": "a",
            "recognizer": "canary",
            "locale": "en",
            "examinationTypeId": "kidneys",
            "text": "Left kidney",
        },
        {
            "id": "canary/b",
            "matrixCaseId": "b",
            "recognizer": "canary",
            "locale": "en",
            "examinationTypeId": "kidneys",
            "text": "Right kidney",
        },
    ]
    source.write_text("".join(json.dumps(row) + "\n" for row in cases))
    token_file = tmp_path / "token.txt"
    requests: list[dict] = []
    active = 0
    maximum_active = 0

    async def handler(request: httpx.Request) -> httpx.Response:
        nonlocal active, maximum_active
        assert request.url.host == "127.0.0.1"
        assert request.url.path == "/v1/ultrasound/parse_dictation"
        assert request.headers["X-Firebase-AppCheck"] == "test-app-check-token"
        assert request.headers["Accept-Language"] == "en"
        body = json.loads(request.content)
        assert body["selectedNeuralModelId"] == "google/medgemma-4b-it"
        requests.append(body)
        active += 1
        maximum_active = max(maximum_active, active)
        await asyncio.sleep(0.02)
        active -= 1
        return httpx.Response(200, json={"proposals": []})

    def refresh(**kwargs: object) -> None:
        token_file.write_text("test-app-check-token")

    original_client = httpx.AsyncClient
    monkeypatch.setattr(
        server_matrix_parse.httpx,
        "AsyncClient",
        lambda **kwargs: original_client(transport=httpx.MockTransport(handler), **kwargs),
    )
    monkeypatch.setattr(server_matrix_parse, "refresh_matrix_app_check", refresh)
    monkeypatch.setattr(server_matrix_parse, "REQUEST_INTERVAL_SECONDS", 0.001)
    output = tmp_path / "results.jsonl"
    profile = tmp_path / "profile.json"
    profile.write_text(
        json.dumps(
            {
                "modelRevision": "test-revision",
                "promptSha256": "a" * 64,
                "generationParameters": {"temperature": 0, "maxTokens": 2048},
                "serverBuildId": "test-build",
            }
        )
    )
    asyncio.run(
        server_matrix_parse.run_server_matrix_parse(
            inputs=[source], output=output, token_file=token_file, device_id="test-device", generation_profile=profile
        )
    )
    rows = [json.loads(line) for line in output.read_text().splitlines()]
    assert len(requests) == 2
    # A later ASR shard may reuse this measured generation only for the exact
    # same language, examination type and corrected transcript.
    later_source = tmp_path / "later-input.jsonl"
    later_source.write_text(json.dumps({**cases[0], "id": "gigaam/a", "recognizer": "gigaam"}) + "\n")
    later_output = tmp_path / "later-output.jsonl"
    asyncio.run(
        server_matrix_parse.run_server_matrix_parse(
            inputs=[later_source],
            output=later_output,
            token_file=token_file,
            device_id="test-device",
            reuse_results=[output],
            generation_profile=profile,
        )
    )
    reused = json.loads(later_output.read_text())
    assert len(requests) == 2
    assert reused["isGenerationReused"] is True
    assert reused["generationOrigin"]["path"] == str(output)
    assert reused["generationModelId"] == "google/medgemma-4b-it"
    changed_profile = tmp_path / "changed-profile.json"
    changed_profile.write_text(json.dumps({**json.loads(profile.read_text()), "serverBuildId": "changed-build"}))
    for other_profile in (None, changed_profile):
        with pytest.raises(ValueError, match="generation profile|different model or runner"):
            asyncio.run(
                server_matrix_parse.run_server_matrix_parse(
                    inputs=[later_source],
                    output=tmp_path / ("no-profile.jsonl" if other_profile is None else "changed-profile.jsonl"),
                    token_file=token_file,
                    device_id="test-device",
                    reuse_results=[output],
                    generation_profile=other_profile,
                )
            )
    with pytest.raises(ValueError, match="different model or runner"):
        asyncio.run(
            server_matrix_parse.run_server_matrix_parse(
                inputs=[later_source],
                output=tmp_path / "other-model.jsonl",
                token_file=token_file,
                device_id="test-device",
                model_id="google/medgemma-1.5-4b-it",
                reuse_results=[output],
                generation_profile=profile,
            )
        )
    assert len(requests) == 2
    assert maximum_active == 2
    assert {row["id"] for row in rows} == {row["id"] for row in cases}
    assert sum(row["isGenerationReused"] for row in rows) == 1
    assert "test-app-check-token" not in output.read_text()
    # Resuming a complete run must neither refresh credentials nor call a model.
    asyncio.run(
        server_matrix_parse.run_server_matrix_parse(
            inputs=[source], output=output, token_file=token_file, device_id="test-device", generation_profile=profile
        )
    )
    assert len(requests) == 2


def test_server_matrix_refuses_a_remote_main_backend(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="locally running main"):
        asyncio.run(
            server_matrix_parse.run_server_matrix_parse(
                inputs=[],
                output=tmp_path / "results.jsonl",
                token_file=tmp_path / "token.txt",
                device_id="test-device",
                base_url="https://dev.api.doglyad.ru",
            )
        )


@pytest.mark.parametrize("failure_kind", ["invalidGeneration", "backendInternalError"])
def test_invalid_model_answer_is_preserved_without_retrying_until_success(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, failure_kind: str
) -> None:
    source = tmp_path / "inputs.jsonl"
    source.write_text(
        json.dumps(
            {
                "id": "canary/a",
                "matrixCaseId": "a",
                "recognizer": "canary",
                "locale": "en",
                "examinationTypeId": "kidneys",
                "text": "Left kidney",
            }
        )
        + "\n"
    )
    token_file = tmp_path / "token.txt"
    requests = 0

    async def handler(request: httpx.Request) -> httpx.Response:
        nonlocal requests
        requests += 1
        # A second attempt would succeed, so a retry would bias the quality
        # measurement by replacing the observed invalid generation.
        if requests == 1:
            return (
                httpx.Response(502, json={"detail": "Invalid voice parse response"})
                if failure_kind == "invalidGeneration"
                else httpx.Response(500, text="Internal Server Error")
            )
        return httpx.Response(200, json={"proposals": []})

    def refresh(**kwargs: object) -> None:
        token_file.write_text("test-app-check-token")

    original_client = httpx.AsyncClient
    monkeypatch.setattr(
        server_matrix_parse.httpx,
        "AsyncClient",
        lambda **kwargs: original_client(transport=httpx.MockTransport(handler), **kwargs),
    )
    monkeypatch.setattr(server_matrix_parse, "refresh_matrix_app_check", refresh)
    output = tmp_path / "results.jsonl"
    for _ in range(2):
        asyncio.run(
            server_matrix_parse.run_server_matrix_parse(
                inputs=[source], output=output, token_file=token_file, device_id="test-device"
            )
        )
    rows = [json.loads(line) for line in output.read_text().splitlines()]
    assert requests == len(rows) == 1
    assert rows[0]["status"] == "failed"
    assert rows[0]["failureKind"] == failure_kind
    assert rows[0]["serverResponse"] is None


def test_saved_results_without_settings_are_not_adopted(tmp_path: Path) -> None:
    output = tmp_path / "results.jsonl"
    output.write_text('{"id":"unknown"}\n')
    with pytest.raises(ValueError, match="no original settings"):
        asyncio.run(
            server_matrix_parse.run_server_matrix_parse(
                inputs=[], output=output, token_file=tmp_path / "token", device_id="test"
            )
        )
    assert not output.with_suffix(".settings.json").exists()
