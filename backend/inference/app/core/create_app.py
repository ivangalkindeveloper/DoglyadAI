from __future__ import annotations

from fastapi import APIRouter, Depends, FastAPI

from app.core.api_error_handler import ApiErrorHandler
from app.core.api_error_middleware import ApiErrorMiddleware
from app.core.inference_lifespan import InferenceLifespan
from app.core.request_body_limit_middleware import RequestBodyLimitMiddleware
from app.core.request_id_middleware import request_id_middleware
from app.core.variables import Variables
from app.core.verify_app_check import verify_app_check
from app.model.inference_server_config import InferenceServerConfig
from app.route.generation import router as generation_router
from app.route.generation_stream import router as generation_stream_router


def create_app(
    variables: Variables | None = None,
) -> FastAPI:
    settings = variables if variables is not None else Variables()
    server = InferenceServerConfig.model_validate_json(
        (settings.configuration_directory / "server.json").read_text(
            encoding="utf-8",
        ),
    )
    error_handler = ApiErrorHandler()
    app = FastAPI(
        responses=error_handler.responses(),
        lifespan=InferenceLifespan,
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
    )
    error_handler.register(
        app,
    )
    app.state.variables = settings
    app.state.server_config = server
    router = APIRouter(
        prefix="/v1",
        dependencies=[
            Depends(
                verify_app_check,
            )
        ],
    )
    router.include_router(
        generation_router,
    )
    router.include_router(
        generation_stream_router,
    )
    app.include_router(
        router,
    )
    app.add_middleware(
        RequestBodyLimitMiddleware,
        limits=dict.fromkeys(
            ("/v1/generation", "/v1/generation/stream"),
            server.generation.max_body_bytes,
        ),
        default_limit=server.default_max_body_bytes,
        error_handler=error_handler,
    )
    app.middleware(
        "http",
    )(
        request_id_middleware,
    )
    app.add_middleware(
        ApiErrorMiddleware,
        error_handler=error_handler,
    )
    return app
