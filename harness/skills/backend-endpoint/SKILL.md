---
name: backend-endpoint
description: Add a new HTTP endpoint to the Doglyad FastAPI backend with camelCase models, App Check, configured request limits, and dependency-injected services.
---

# Add a FastAPI backend endpoint

Create and fully integrate an endpoint according to `AGENTS.md`. The main backend
uses Python 3.11, FastAPI, Pydantic and one shared `httpx.AsyncClient`.

## Read the current implementation

Use `app/route/ultrasound/generate_report.py` for a service-backed operation,
`app/route/email/send_report_email.py` for a bodyless response, and
`app/route/templates/ready_made_list.py` for localized configuration data.
Read `app/core/application/application_factory.py` and `main_lifespan.py` for composition.

## Place the implementation

- Put routes under `backend/main/app/route/`, grouped by feature.
- Put each request/response model in its own file under `app/model/`; ultrasound
  models live under `app/model/ultrasound/` with the `US` prefix.
- Put business logic in the owning `app/service/<feature>/` package.
- Put typed service getters on `ServiceDependencies` in
  `app/core/application/service_dependencies.py`; return the ready instance from
  `MainContainer`. Owner/feature checks belong to `BillingDependencies` and language
  selection to `LocalizationDependencies`.
- Compose services once through `ServiceFactory` during `MainLifespan`; add an owned
  dependency to `MainContainer` when the endpoint needs a new service. Factories
  create services; request dependencies do not construct them again.

Keep files named after their one public declaration. Do not add implementations
or compatibility exports to the `core` or `service` package roots.

## Preserve the endpoint contract

1. Choose the method, versioned path, request and response before writing the route.
2. Use camelCase Pydantic fields. Every HTTP response model, including nested
   models, has the `Response` suffix. Keep required response strings nonblank and
   normalize blank optional strings to `None`.
3. Inject services through `Annotated[Service, Depends(get_service)]`. Keep request
   validation and HTTP adaptation in the route; business logic belongs in services.
4. Use `async`/`await` and the lifespan-owned HTTP client. Run blocking SMTP work
   through `asyncio.to_thread`. Never create per-request HTTP clients or global
   catalogs/services.
5. Read environment values through `Variables` in
   `app/core/configuration/variables.py`. Read operational policies from the loaded
   server configuration. Never modify secret files or hardcode credentials.
6. Raise a concrete `ApiError` from `app/error/` for expected failures. The shared
   `ApiErrorHandler` owns formatting and safe logging. Never expose exception
   strings, validation inputs or patient data in logs.

Use `LanguageCode` and `HttpHeader` through `core/localization/` and `core/http/`.
Resolve the request language through `get_request_language` rather than duplicating
header parsing or hardcoding RU/EN strings.

## Register and protect the route

Include the feature router in `app/core/application/application_factory.py`. All client
endpoints live under `/v1`; App Check and request limiting are attached to this
router unconditionally, including configuration endpoints.

Add the full path to `endpoints` in both environments' `server.json`, with the
appropriate rate and body-size policies. Startup verifies exact route/policy
coverage. Use the existing `RequestLimiter`; do not add SlowAPI decorators or
literal rate settings in routes.

Owner-specific subscription operations also require the anonymous bearer secret.
Provider callbacks belong to the separately verified payment ingress, never to an
unprotected client API. Do not invent a public configuration exception.

## Add inference only when required

Call the ready `NeuralModelService` through an owning application service. Build
prompts with `PromptFactory` and loaded localization, then submit the internal
`NeuralModelServiceRequest`. The main backend never runs model inference.

`app/service/neural_model/neural_model_service_factory.py` selects the implementation once
from `MODEL_SERVICE_TYPE`; `ENVIRONMENT` selects documents only. Do not duplicate
model selection or GPU routing in the endpoint.

## Finish

- Update the corresponding iOS `Domain/` request/response models and repository,
  preserving camelCase. Application models have no `DTO` suffix.
- Add relevant contract, validation and authorization checks. A request without
  App Check must return `401`; verify owner isolation where applicable.
- Run the relevant checks from the `build-verify` skill; do not deploy just to
  validate a new route.
- Report the endpoint, resulting behavior and verification.
