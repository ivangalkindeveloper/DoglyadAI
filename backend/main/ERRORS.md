# API errors

Both Python services use the same error response contract:

```json
{
  "code": "imageTooLarge",
  "detail": "Image is too large",
  "requestId": "17e509165eba4d00b7c71d5dcb72b137"
}
```

`requestId` matches the `X-Request-ID` response header. Main creates an ID and forwards it to inference; inference preserves valid forwarded IDs. Clients should use `code` and HTTP status for decisions. Descriptions are technical API text; physician-facing UI messages remain in main's localization catalogs.

Input validation adds `fields`:

```json
{
  "code": "invalidRequest",
  "detail": "Request validation failed",
  "requestId": "17e509165eba4d00b7c71d5dcb72b137",
  "fields": [
    {
      "location": ["body", "settingsAI", "maxTokens"],
      "code": "less_than_equal",
      "description": "Value exceeds the allowed maximum"
    }
  ]
}
```

Validation responses contain declared field locations and safe descriptions. They omit input values, raw validation messages, error context and arbitrary unknown key names. `fields` is omitted for other errors. OpenAPI documents `ApiErrorResponse` for error statuses.

## Ownership

- `app/error/`: one class per expected API failure. Each class defines a stable lower camel case `code`, a nonblank public `description` and `status_code`. Related report validation failures derive from `InvalidReportResponseError`. Retryable errors own their `Retry-After` metadata.
- `ApiErrorHandler`: builds `ApiErrorResponse`, registers FastAPI exception handlers, handles framework 404/405 and request-validation failures, and logs failures safely. Body-limit middleware uses this same formatter.
- `ApiErrorMiddleware`: an outer ASGI boundary for unexpected exceptions, including failures in other middleware. It prevents raw exceptions from escaping to the server's exception logger. Before response headers are sent it returns a safe `500`; after a response has started it logs the failure without sending a second response. Cancellation propagates normally.
- `ApiErrorResponse` and `ApiValidationIssueResponse`: Pydantic response contracts with camelCase fields.

The implementations are local to each independently deployed service. Contract tests verify the schemas and metadata of shared error types agree.

## Raising and translating errors

Keep checks beside the rule they enforce:

```python
if len(decoded) > self._max_image_bytes:
    raise ImageTooLargeError()
```

Translate known external failures at the integration boundary, preserving the cause:

```python
except httpx.TimeoutException as cause:
    raise InferenceTimeoutError() from cause
```

Services do not build HTTP responses or repeat public descriptions. Expected failures are logged once by the API boundary. Logs contain the public error code, status and cause category; unexpected failures also include traceback file/function/line locations. They never render exception messages, causes, arguments, source lines, input values or local variables.

Pydantic model validators use `ValueError` or Pydantic's validation mechanisms. An invalid request becomes `422`; invalid generated content is translated to an appropriate `502` error at the generation boundary. A global mapping from arbitrary `ValueError` to a client error would misclassify generation failures and programming errors.

Startup configuration failures still abort startup with diagnostic exceptions. They are not HTTP responses. SMTP handling catches SMTP/network failures; unexpected programming errors reach the common `500` boundary. `503` capacity errors retain `Retry-After`, and transport deadlines use `504`.
