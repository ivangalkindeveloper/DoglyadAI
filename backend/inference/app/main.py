from __future__ import annotations

from fastapi import APIRouter, Depends, FastAPI

from app.core.inference_lifespan import InferenceLifespan
from app.core.request_id_middleware import request_id_middleware
from app.core.setup_logging import setup_logging
from app.core.verify_app_check import verify_app_check
from app.route.generation import router as generation_router

setup_logging()

router_v1 = APIRouter(prefix="/v1", dependencies=[Depends(verify_app_check)])
router_v1.include_router(generation_router)

app = FastAPI(lifespan=InferenceLifespan, docs_url=None, redoc_url=None, openapi_url=None)
app.middleware("http")(request_id_middleware)
app.include_router(router_v1)
