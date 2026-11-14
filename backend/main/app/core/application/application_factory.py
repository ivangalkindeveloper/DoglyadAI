from __future__ import annotations

from fastapi import APIRouter, Depends, FastAPI
from fastapi.routing import APIRoute

from app.core.app_check.app_check import AppCheck
from app.core.application.main_lifespan import MainLifespan
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.configuration.variables import Variables
from app.core.http.api_error_handler import ApiErrorHandler
from app.core.http.api_error_middleware import ApiErrorMiddleware
from app.core.http.http_request_policy import HttpRequestPolicy
from app.core.http.request_body_limit_middleware import RequestBodyLimitMiddleware
from app.core.http.request_id_middleware import RequestIdMiddleware
from app.model.endpoint_config import EndpointConfig
from app.model.main_server_config import MainServerConfig
from app.route.configuration.application_config import router as application_config_router
from app.route.email.send_report_email import router as send_report_email_router
from app.route.localization.l10n import router as l10n_router
from app.route.subscription import router as subscription_router
from app.route.templates import router as templates_router
from app.route.ultrasound import router as ultrasound_router
from app.service.billing.payment_gateway import PaymentGateway
from app.service.http.request_limiter import RequestLimiter


class ApplicationFactory:
    def __init__(
        self,
    ) -> None:
        pass

    @classmethod
    def create_main(
        cls,
        variables: Variables | None = None,
    ) -> FastAPI:
        settings = variables if variables is not None else Variables()
        server = ConfigurationLoader(
            settings.configuration_directory,
        ).load_server()
        handler = ApiErrorHandler()
        app = FastAPI(
            responses=handler.responses(),
            lifespan=MainLifespan,
            docs_url=None,
            redoc_url=None,
            openapi_url=None,
        )
        router = APIRouter(
            prefix="/v1",
            dependencies=[
                Depends(
                    AppCheck.verify,
                ),
                Depends(
                    HttpRequestPolicy.enforce_limit,
                ),
            ],
        )
        for child in (
            application_config_router,
            l10n_router,
            ultrasound_router,
            templates_router,
            send_report_email_router,
            subscription_router,
        ):
            router.include_router(
                child,
            )
        app.include_router(
            router,
        )
        cls._configure(
            app,
            settings,
            server,
            {
                path: policy
                for path, policy in server.endpoints.items()
                if path.startswith(
                    "/v1/",
                )
            },
            handler,
        )
        return app

    @classmethod
    def create_payment(
        cls,
        variables: Variables | None = None,
    ) -> FastAPI:
        settings = variables if variables is not None else Variables()
        server = ConfigurationLoader(
            settings.configuration_directory,
        ).load_server()
        app = FastAPI(
            lifespan=MainLifespan,
            docs_url=None,
            redoc_url=None,
            openapi_url=None,
            dependencies=[
                Depends(
                    HttpRequestPolicy.enforce_limit,
                )
            ],
        )
        gateway = PaymentGateway()
        for path, method, endpoint in (
            ("/payments/return", "GET", gateway.return_to_application),
            ("/webhooks/robokassa", "POST", gateway.robokassa),
            ("/webhooks/apple", "POST", gateway.apple),
        ):
            app.add_api_route(
                path,
                endpoint,
                methods=[method],
            )
        cls._configure(
            app,
            settings,
            server,
            {
                path: policy
                for path, policy in server.endpoints.items()
                if not path.startswith(
                    "/v1/",
                )
            },
            ApiErrorHandler(),
        )
        return app

    @staticmethod
    def _configure(
        app: FastAPI,
        variables: Variables,
        server: MainServerConfig,
        endpoints: dict[str, EndpointConfig],
        handler: ApiErrorHandler,
    ) -> None:
        paths = {
            route.path
            for route in app.routes
            if isinstance(
                route,
                APIRoute,
            )
        }
        if paths != set(
            endpoints,
        ):
            raise RuntimeError(
                "Server endpoint configuration must match application routes",
            )
        app.state.variables = variables
        app.state.server_config = server
        app.state.request_limiter = RequestLimiter(
            endpoints,
        )
        handler.register(
            app,
        )
        app.add_middleware(
            RequestBodyLimitMiddleware,
            limits={path: policy.max_body_bytes for path, policy in endpoints.items()},
            default_limit=server.default_max_body_bytes,
            error_handler=handler,
        )
        app.add_middleware(
            RequestIdMiddleware,
        )
        app.add_middleware(
            ApiErrorMiddleware,
            error_handler=handler,
        )
