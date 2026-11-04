from __future__ import annotations

import json
from typing import Any

import pytest

from app.service.structured_output_reader import StructuredOutputReader


@pytest.mark.parametrize(
    "width",
    [1, 2, 7, 1000],
)
def test_nested_json_strings_and_escapes_split_at_any_boundary(
    width: int,
) -> None:
    value = {"items": [{"text": 'Кавычка: " скобки: } ] { [ обратный слеш: \\ конец'}], "null": None}
    text = json.dumps(
        value,
        ensure_ascii=False,
        indent=2,
    )
    reader = StructuredOutputReader(
        {"type": "object", "required": ["items", "null"]},
    )
    result = []
    for start in range(
        0,
        len(
            text,
        ),
        width,
    ):
        assert not reader.is_complete
        result.append(
            reader.append(
                text[start : start + width],
            ),
        )
    assert reader.is_complete
    assert (
        "".join(
            result,
        )
        == text
    )


@pytest.mark.parametrize(
    "text",
    ["{}", '[{"a": []}]', '"hello } \\" world"'],
)
def test_self_delimited_root_completes_and_removes_only_trailing_whitespace(
    text: str,
) -> None:
    reader = StructuredOutputReader(
        {},
    )
    assert (
        reader.append(
            text + "\n\t  ",
        )
        == text
    )
    assert reader.is_complete


@pytest.mark.parametrize(
    "pieces",
    [["1", "2"], ["1", ".", "5"], ["n", "ull"], ["tr", "ue"]],
)
def test_scalar_waits_for_the_upstream_finish(
    pieces: list[str],
) -> None:
    reader = StructuredOutputReader(
        {},
    )
    for part in pieces:
        assert (
            reader.append(
                part,
            )
            == part
        )
        assert not reader.is_complete
    reader.finish()
    assert reader.is_complete


@pytest.mark.parametrize(
    "text",
    [
        '{"a":1',
        '{"a":"unfinished',
        '{"a":[}',
        '{"a":1,}',
        "{}{}",
        "{} trailing",
        '{"a":NaN}',
        '{"a":1,"a":2}',
        '"invalid\\x"',
        "",
        "   ",
    ],
)
def test_invalid_or_incomplete_json_never_completes(
    text: str,
) -> None:
    reader = StructuredOutputReader(
        {},
    )
    with pytest.raises(
        ValueError,
    ):
        reader.append(
            text,
        )
        reader.finish()
    assert not reader.is_complete


@pytest.mark.parametrize(
    "schema,text",
    [
        ({"type": "object", "required": ["description"]}, "{}"),
        ({"type": "object", "properties": {"n": {"type": "integer"}}}, '{"n":"one"}'),
        ({"type": "object", "additionalProperties": False}, '{"extra":1}'),
        ({"type": "array", "maxItems": 1}, "[1,2]"),
        ({"type": "string", "enum": ["a"]}, '"b"'),
        ({"type": "string", "format": "uuid"}, '"bad"'),
        ({"$ref": "https://example.invalid/never-fetch"}, "{}"),
    ],
)
def test_closed_json_must_match_schema(
    schema: dict[str, Any],
    text: str,
) -> None:
    reader = StructuredOutputReader(
        schema,
    )
    with pytest.raises(
        ValueError,
    ):
        reader.append(
            text,
        )
    assert not reader.is_complete


def test_local_schema_references_work() -> None:
    reader = StructuredOutputReader(
        {"$defs": {"item": {"type": "integer"}}, "type": "array", "items": {"$ref": "#/$defs/item"}},
    )
    reader.append(
        "[1,2]",
    )
    assert reader.is_complete


def test_invalid_schema_is_rejected() -> None:
    with pytest.raises(
        ValueError,
    ):
        StructuredOutputReader(
            {"type": "not-a-json-type"},
        )
