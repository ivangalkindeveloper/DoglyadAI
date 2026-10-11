from __future__ import annotations

import asyncio

import pytest
from fastapi import HTTPException

from app.core.verify_app_check import APP_CHECK_HEADER, verify_app_check


def test_every_v1_route_is_behind_app_check() -> None:
    # Guards the wiring, not just the intent: dropping `dependencies=` from the
    # router in app/main.py would otherwise leave every other test green. There is
    # no environment in which this is relaxed — the backend has no unauthenticated
    # surface beyond what FastAPI itself serves.
    from app.main import app

    routes = [route for route in app.routes if str(getattr(route, "path", "")).startswith("/v1/")]
    assert routes

    for route in routes:
        dependencies = [call.call for call in route.dependant.dependencies]  # type: ignore[attr-defined]
        assert verify_app_check in dependencies, f"{route.path} is not behind App Check"


def test_missing_token_is_rejected() -> None:
    # Rejected at the edge before any service is resolved. The GPU VM performs a
    # second independent verification when the request reaches it.
    with pytest.raises(HTTPException) as error:
        asyncio.run(verify_app_check(None))

    assert error.value.status_code == 401


def test_header_name_matches_the_one_the_inference_service_reads() -> None:
    # Relayed verbatim to the GPU VM, which looks the token up under this name.
    assert APP_CHECK_HEADER == "X-Firebase-AppCheck"
