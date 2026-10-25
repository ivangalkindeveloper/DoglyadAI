from __future__ import annotations

from fastapi import APIRouter, Depends, FastAPI
from fastapi.routing import APIRoute

from app.core.api_error_handler import ApiErrorHandler
from app.core.api_error_middleware import ApiErrorMiddleware
from app.core.configuration_loader import ConfigurationLoader
from app.core.enforce_request_limit import enforce_request_limit
from app.core.main_lifespan import MainLifespan
from app.core.request_body_limit_middleware import RequestBodyLimitMiddleware
from app.core.request_id_middleware import request_id_middleware
from app.core.variables import Variables
from app.core.verify_app_check import verify_app_check
from app.route.application_config import router as application_config_router
from app.route.l10n import router as l10n_router
from app.route.send_report_email import router as send_report_email_router
from app.route.templates import router as templates_router
from app.route.ultrasound import router as ultrasound_router
from app.service.request_limiter import RequestLimiter


def create_app(variables: Variables | None = None) -> FastAPI:
    settings = variables if variables is not None else Variables()
    server = ConfigurationLoader(settings.configuration_directory).load_server()
    error_handler = ApiErrorHandler()
    app = FastAPI(responses=error_handler.responses(), lifespan=MainLifespan)
    error_handler.register(app)
    app.state.variables = settings
    app.state.server_config = server
    app.state.request_limiter = RequestLimiter(server.endpoints)
    router = APIRouter(prefix="/v1", dependencies=[Depends(verify_app_check), Depends(enforce_request_limit)])
    for child in (
        application_config_router,
        l10n_router,
        ultrasound_router,
        templates_router,
        send_report_email_router,
    ):
        router.include_router(child)
    paths = {route.path for route in router.routes if isinstance(route, APIRoute)}
    if paths != set(server.endpoints):
        raise RuntimeError("Server endpoint configuration must match application routes")
    app.include_router(router)
    app.add_middleware(
        RequestBodyLimitMiddleware,
        limits={path: config.max_body_bytes for path, config in server.endpoints.items()},
        default_limit=server.default_max_body_bytes,
        error_handler=error_handler,
    )
    app.middleware("http")(request_id_middleware)
    app.add_middleware(ApiErrorMiddleware, error_handler=error_handler)
    return app
