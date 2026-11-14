from __future__ import annotations

from fastapi import APIRouter, Depends

from app.core.http.http_request_policy import HttpRequestPolicy
from app.route.subscription.auto_renewal import router as auto_renewal_router
from app.route.subscription.check_payment import router as check_payment_router
from app.route.subscription.plans import router as plans_router
from app.route.subscription.prepare_payment import router as prepare_payment_router
from app.route.subscription.recover import router as recover_router
from app.route.subscription.recovery_key import router as recovery_key_router
from app.route.subscription.register import router as register_router
from app.route.subscription.status import router as status_router
from app.route.subscription.sync_apple import router as sync_apple_router

router = APIRouter(
    prefix="/subscriptions",
    dependencies=[
        Depends(
            HttpRequestPolicy.prevent_cache,
        )
    ],
)
for child in (
    register_router,
    plans_router,
    status_router,
    prepare_payment_router,
    check_payment_router,
    recovery_key_router,
    recover_router,
    auto_renewal_router,
    sync_apple_router,
):
    router.include_router(
        child,
    )
