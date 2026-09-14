from __future__ import annotations

from fastapi import APIRouter, Depends, FastAPI
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.core.app_check import verify_app_check
from app.core.limiter import limiter
from app.core.logging import setup_logging
from app.core.main_lifespan import MainLifespan
from app.route.application_config import router as application_config_router
from app.route.send_report_email import router as send_report_email_router
from app.route.templates import router as templates_router
from app.route.ultrasound import router as ultrasound_router

setup_logging()

router_v1 = APIRouter(prefix="/v1", dependencies=[Depends(verify_app_check)])
router_v1.include_router(application_config_router)
router_v1.include_router(ultrasound_router)
router_v1.include_router(templates_router)
router_v1.include_router(send_report_email_router)

app = FastAPI(lifespan=MainLifespan)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)  # type: ignore[arg-type]
app.include_router(router_v1)
