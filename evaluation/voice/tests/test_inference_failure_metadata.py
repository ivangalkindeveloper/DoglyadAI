from evaluation.voice.runners.inference_failure_metadata import parse_failure_metadata


def test_truncated_invalid_json_is_a_generation_failure_with_token_evidence() -> None:
    request_id = "a" * 32
    log = "\n".join(
        f"request_id={request_id}: {line}"
        for line in [
            "vLLM response: status=200",
            "finish_reason=length, prompt_tokens=1416, completion_tokens=2048",
            "Failed to parse vLLM response: JSONDecodeError",
        ]
    )
    result = parse_failure_metadata(log, request_id)
    assert result["isModelGenerationFailure"] is True
    assert result["finishReason"] == "length"
    assert result["completionTokens"] == 2048


def test_concurrent_requests_cannot_inherit_another_generations_failure() -> None:
    current = "a" * 32
    other = "b" * 32
    log = (
        f"request_id={current}: vLLM response: status=200\n"
        f"request_id={current}: finish_reason=stop, prompt_tokens=1000, completion_tokens=500\n"
        f"request_id={other}: finish_reason=length, prompt_tokens=1416, completion_tokens=2048\n"
        f"request_id={other}: Failed to parse vLLM response: JSONDecodeError\n"
    )
    result = parse_failure_metadata(log, current)
    assert result["isModelGenerationFailure"] is False
    assert result["parseError"] is None
