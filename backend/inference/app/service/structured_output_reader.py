from __future__ import annotations

import json
from typing import Any

from jsonschema.exceptions import SchemaError, ValidationError
from jsonschema.validators import validator_for
from referencing import Registry
from referencing.exceptions import Unresolvable


class StructuredOutputReader:
    """Recognize one complete JSON value without confusing string data with syntax."""

    def __init__(
        self,
        schema: dict[str, Any],
    ) -> None:
        validator_type = validator_for(
            schema,
        )
        try:
            validator_type.check_schema(
                schema,
            )
        except SchemaError as error:
            raise ValueError(
                "Invalid output schema",
            ) from error
        # Local $defs/$ref work; validation must never fetch external resources.
        self._validator = validator_type(
            schema,
            registry=Registry(),
            format_checker=validator_type.FORMAT_CHECKER,
        )
        self._pieces: list[str] = []
        self._stack: list[str] = []
        self._is_started = False
        self._is_in_string = False
        self._is_escaped = False
        self._is_scalar = False
        self._is_complete = False

    @property
    def is_complete(
        self,
    ) -> bool:
        return self._is_complete

    def append(
        self,
        text: str,
    ) -> str:
        if self._is_complete:
            raise ValueError(
                "JSON value is already complete",
            )
        for index, character in enumerate(
            text,
        ):
            if not self._is_started:
                if character in " \t\r\n":
                    continue
                self._is_started = True
                self._is_scalar = character not in '{["'
            if self._is_scalar:
                # A numeric prefix such as 1 can still become 12 or 1.5.
                # Unframed scalar values require the normal upstream finish.
                continue
            if self._is_in_string:
                if self._is_escaped:
                    self._is_escaped = False
                elif character == "\\":
                    self._is_escaped = True
                elif character == '"':
                    self._is_in_string = False
                    if not self._stack:
                        return self._complete(
                            text,
                            index + 1,
                        )
            elif character == '"':
                self._is_in_string = True
            elif character in "{[":
                self._stack.append(
                    "}" if character == "{" else "]",
                )
            elif character in "}]":
                if not self._stack or character != self._stack.pop():
                    raise ValueError(
                        "Mismatched JSON delimiters",
                    )
                if not self._stack:
                    return self._complete(
                        text,
                        index + 1,
                    )
        self._pieces.append(
            text,
        )
        return text

    def finish(
        self,
    ) -> None:
        if not self._is_complete:
            self._validate()
            self._is_complete = True

    def _complete(
        self,
        text: str,
        end: int,
    ) -> str:
        if text[end:].strip(
            " \t\r\n",
        ):
            raise ValueError(
                "Unexpected data after JSON value",
            )
        content = text[:end]
        self._pieces.append(
            content,
        )
        self._validate()
        self._is_complete = True
        return content

    def _validate(
        self,
    ) -> None:
        value = json.loads(
            "".join(
                self._pieces,
            ),
            parse_constant=self._reject_constant,
            object_pairs_hook=self._unique_object,
        )
        try:
            self._validator.validate(
                value,
            )
        except (ValidationError, Unresolvable, RecursionError) as error:
            raise ValueError(
                "Generated JSON does not satisfy its schema",
            ) from error

    @staticmethod
    def _reject_constant(
        value: str,
    ) -> None:
        raise ValueError(
            "Non-JSON numeric constant",
        )

    @staticmethod
    def _unique_object(
        pairs: list[tuple[str, Any]],
    ) -> dict[str, Any]:
        value: dict[str, Any] = {}
        for key, item in pairs:
            if key in value:
                raise ValueError(
                    "Duplicate JSON property",
                )
            value[key] = item
        return value
