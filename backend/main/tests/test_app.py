from __future__ import annotations


def test_app_exposes_v1_routes() -> None:
    from app.main import app

    paths = {getattr(route, "path", None) for route in app.routes}
    assert "/v1/application_config" in paths
    assert "/v1/ultrasound/examination_types" in paths
    assert "/v1/ultrasound/examination_neural_models" in paths
    assert "/v1/ultrasound/examination_contextual_strings" in paths
    assert "/v1/ultrasound/generate_report" in paths
    assert "/v1/templates/ready_made_list" in paths
    assert "/v1/send_report_email" in paths
    assert "/application_config" not in paths
    assert "/v1/ultrasound/send_report_email" not in paths
    assert "/v1/ultrasound_report" not in paths
