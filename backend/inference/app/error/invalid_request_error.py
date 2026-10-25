from __future__ import annotations

from typing import ClassVar

from app.error.api_error import ApiError


class InvalidRequestError(ApiError):
    code = "invalidRequest"
    description = "Request validation failed"
    status_code = 422
    _field_descriptions: ClassVar[dict[str, str]] = {
        "missing": "Field is required",
        "extra_forbidden": "Unexpected field",
        "json_invalid": "Invalid JSON document",
        "json_type": "Expected a JSON document",
        "string_type": "Expected text",
        "string_too_short": "Text is shorter than the allowed minimum",
        "string_too_long": "Text exceeds the allowed length",
        "string_pattern_mismatch": "Text does not match the required format",
        "int_type": "Expected an integer",
        "int_parsing": "Expected an integer",
        "float_type": "Expected a number",
        "float_parsing": "Expected a number",
        "bool_type": "Expected a boolean",
        "bool_parsing": "Expected a boolean",
        "list_type": "Expected a list",
        "dict_type": "Expected an object",
        "model_type": "Expected an object",
        "model_attributes_type": "Expected an object",
        "greater_than": "Value must exceed the allowed minimum",
        "greater_than_equal": "Value is below the allowed minimum",
        "less_than": "Value must be below the allowed maximum",
        "less_than_equal": "Value exceeds the allowed maximum",
        "finite_number": "Expected a finite number",
        "enum": "Value is not a supported option",
        "literal_error": "Value is not a supported option",
        "uuid_parsing": "Expected a valid UUID",
        "datetime_from_date_parsing": "Expected a valid date and time",
        "datetime_parsing": "Expected a valid date and time",
        "date_from_datetime_parsing": "Expected a valid date",
        "value_error": "Invalid field value",
    }

    @classmethod
    def field_description(cls, code: str) -> str:
        return cls._field_descriptions.get(code, "Invalid field value")
