from __future__ import annotations

from fastapi import APIRouter

from app.route.templates.ready_made_list import router as ready_made_list_router

router = APIRouter(prefix="/templates")
router.include_router(ready_made_list_router)
