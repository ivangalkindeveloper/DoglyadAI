from __future__ import annotations

from fastapi import APIRouter

from app.route.ultrasound.examination_contextual_strings import router as examination_contextual_strings_router
from app.route.ultrasound.examination_neural_models import router as examination_neural_models_router
from app.route.ultrasound.examination_types import router as examination_types_router
from app.route.ultrasound.generate_report import router as generate_report_router

router = APIRouter(prefix="/ultrasound")
router.include_router(examination_types_router)
router.include_router(examination_neural_models_router)
router.include_router(examination_contextual_strings_router)
router.include_router(generate_report_router)
