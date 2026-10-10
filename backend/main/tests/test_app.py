from __future__ import annotations

import asyncio
import re

import httpx


def test_app_exposes_v1_routes() -> None:
    from app.main import app

    paths = {getattr(route, "path", None) for route in app.routes}
    assert "/v1/application_config" in paths
    assert "/v1/l10n" in paths
    assert "/l10n" not in paths
    assert "/v1/ultrasound/examination_types" in paths
    assert "/v1/ultrasound/examination_neural_models" in paths
    assert "/v1/ultrasound/examination_contextual_strings" not in paths
    assert "/v1/ultrasound/generate_report" in paths
    assert "/v1/templates/ready_made_list" in paths
    assert "/v1/send_report_email" in paths
    assert "/application_config" not in paths
    assert "/v1/ultrasound/send_report_email" not in paths
    assert "/v1/ultrasound_report" not in paths


def test_main_generates_a_request_id_for_each_request() -> None:
    from app.main import app

    async def run() -> tuple[str, str]:
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            first = await client.get("/openapi.json", headers={"X-Request-ID": "client-supplied"})
            second = await client.get("/openapi.json")
        assert first.status_code == second.status_code == 200
        return first.headers["X-Request-ID"], second.headers["X-Request-ID"]

    first_id, second_id = asyncio.run(run())
    assert re.fullmatch(r"[0-9a-f]{32}", first_id)
    assert re.fullmatch(r"[0-9a-f]{32}", second_id)
    assert first_id != second_id
