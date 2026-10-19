---
name: backend-endpoint
description: Add a new HTTP endpoint to the Doglyad FastAPI backend. Create a /v1 route, camelCase Pydantic request and response models compatible with iOS, apply rate limiting, and register the router in main.py. Use when adding a backend API method.
---

# Add a FastAPI backend endpoint

Create and fully integrate an endpoint according to project conventions. The backend uses Python 3.11, FastAPI, Pydantic, a shared `httpx.AsyncClient`, and SlowAPI.

Use these locations:

- routes: `backend/main/app/route/<name>.py`
- shared models: `backend/main/app/model/`
- ultrasound models: `backend/main/app/model/ultrasound/`
- application assembly: `backend/main/app/main.py`

Before generating code, read `app/route/ultrasound_conclusion.py` for an inference/service example or `app/route/ultrasound_conclusion_send_email.py` for a response without a body. Treat the templates below as scaffolding only.

## Resolve before implementation

1. Choose a snake_case endpoint name, such as `ultrasound_history`. Derive the route file, URL path, and function name from it.
2. Determine the HTTP method and whether the endpoint returns a model or `204 No Content`.
3. Define incoming request fields or confirm that no body is required.
4. Determine whether the route needs LLM inference, external HTTP through the shared client, or local business logic.
5. Determine whether the endpoint belongs behind App Check. Put it under `/v1` by default. Only expose data outside `/v1` when the app must read it before obtaining a token and the data is public by nature, as with configuration endpoints.

## Required conventions

- Put `from __future__ import annotations` at the beginning of each Python file and add type annotations everywhere.
- Use snake_case for functions and variables and CamelCase for classes and Pydantic models.
- Keep Pydantic fields in camelCase because they are part of the iOS contract, for example `settingsAI`, `recipientEmail`, and `modelId`. Do not add aliases to convert them to snake_case.
- Use `async def` for handlers. Reuse `request.app.state.http_client` for external HTTP instead of creating a client per request. Run blocking I/O such as SMTP through `asyncio.to_thread`.
- Read configuration and secrets only through `variables` from `app/core/variables.py`. Never hardcode values or modify `backend/main/secrets/`.
- Raise `HTTPException(status_code=..., detail=...)` for API errors and use a module-level `logger`.
- Apply `@limiter.limit("30/minute")`; keep `request: Request` in the function signature for the limiter.

## Route template

Create `backend/main/app/route/<name>.py`:

```python
from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Request

from app.core.limiter import limiter
from app.core.variables import variables
from app.model.<name>_request import <Name>Request
from app.model.<name>_response import <Name>Response

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/<name>", response_model=<Name>Response)
@limiter.limit("30/minute")
async def <name>(
    body: <Name>Request,
    request: Request,
) -> <Name>Response:
    logger.info("Request <name>: ...")

    # Business logic. For external HTTP, use request.app.state.http_client.
    # For blocking I/O, use await asyncio.to_thread(_blocking_fn, ...).
    # For API errors, raise HTTPException(status_code=400, detail="...").

    return <Name>Response(...)
```

For a response without a body, follow `ultrasound_conclusion_send_email`:

```python
from fastapi import status

@router.post("/<name>", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("30/minute")
async def <name>(body: <Name>Request, request: Request) -> None:
    del request  # Keep the parameter when only the limiter needs it.
    ...
```

## Pydantic model templates

Create `backend/main/app/model/<name>_request.py`, or place ultrasound-domain models under `app/model/ultrasound/` with the `US` prefix:

```python
from __future__ import annotations

from pydantic import BaseModel


class <Name>Request(BaseModel):
    someField: str
    optionalField: str | None = None
```

Create `backend/main/app/model/<name>_response.py`:

```python
from __future__ import annotations

from pydantic import BaseModel


class <Name>Response(BaseModel):
    resultField: str
```

Extract nested models into separate classes or files, following `app/model/ultrasound/`.

## Register the route

In `backend/main/app/main.py`:

1. Import the router beside existing route imports:

```python
from app.route.<name> import router as <name>_router
```

2. Attach it to the router with `prefix="/v1"`:

```python
router_v1.include_router(<name>_router)
```

`Depends(verify_app_check)` is attached to `router_v1`, so the endpoint automatically requires App Check. If the endpoint must be public, attach it directly to `app` and explain the exception in its docstring.

## Add LLM inference only when required

Follow `ultrasound_conclusion.py`:

- Resolve language with `request.headers.get("accept-language", "en")` and `resolve_prompt_factory(language_code)`.
- Read the ready service with `model_service: NeuralModelService = request.app.state.model_service`, then call `await model_service.call(...)`. Do not branch by environment; `create_model_service()` composes the same route during lifespan.
- Use `resolve_neural_model` and `resolve_examination_title` from `app/core/resolve_neural_model.py` and `app/core/resolve_examination_title.py`.
- Add a new inference implementation as a `NeuralModelService` subclass of the contract in `app/service/neural_model_service.py` and compose it only in `app/service/create_model_service.py`.

## Finish

1. Synchronize iOS DTO and domain models when the API contract changes, preserving camelCase fields.
2. Start the backend with `make start-backend-main-development`, exercise `/v1/<name>`, and inspect `make start-backend-main-logs`. A request without an application App Check token must return `401`.
3. Report the created files, endpoint path, and registration point in `main.py`.
