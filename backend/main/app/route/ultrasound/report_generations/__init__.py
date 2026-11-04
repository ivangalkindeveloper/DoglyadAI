from __future__ import annotations

from fastapi import APIRouter

from app.route.ultrasound.report_generations.cancel_report_generation import router as cancel_report_generation_router
from app.route.ultrasound.report_generations.get_report_generation import router as get_report_generation_router
from app.route.ultrasound.report_generations.start_report_generation import router as start_report_generation_router
from app.route.ultrasound.report_generations.stream_report_generation import router as stream_report_generation_router

router = APIRouter()

for generation_router in (
    start_report_generation_router,
    get_report_generation_router,
    cancel_report_generation_router,
    stream_report_generation_router,
):
    router.include_router(
        generation_router,
        prefix="/report_generations",
    )
