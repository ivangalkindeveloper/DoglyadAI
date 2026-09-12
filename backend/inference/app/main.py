from __future__ import annotations

from fastapi import APIRouter, Depends, FastAPI

from app.core.app_check import verify_app_check
from app.core.inference_lifespan import InferenceLifespan
from app.core.logging import setup_logging
from app.route.generation import router as generation_router

setup_logging()

router_v1 = APIRouter(prefix="/v1", dependencies=[Depends(verify_app_check)])
router_v1.include_router(generation_router)

app = FastAPI(lifespan=InferenceLifespan)
app.include_router(router_v1)
