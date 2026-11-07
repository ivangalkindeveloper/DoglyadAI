"""Export the real Development response builders for offline SwiftUI previews."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend/main"))


def documents() -> dict[str, str]:
    from app.core.configuration.configuration_loader import ConfigurationLoader
    from app.core.localization.language_code import LanguageCode
    from app.service.configuration.configuration_response_service import (
        ConfigurationResponseService,
    )
    from app.model.billing.billing_catalog import BillingCatalog
    from app.service.billing.billing_catalog_response_service import (
        BillingCatalogResponseService,
    )

    configuration = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    responses = ConfigurationResponseService(configuration)
    catalog = BillingCatalog.model_validate_json(
        (ROOT / "backend/main/config/development/billing.json").read_text()
    )
    result = {}
    for language in LanguageCode:
        data = {
            "application": responses.application(language),
            "localization": json.loads(responses.l10n_document(language)),
            "examinationTypes": [
                item.model_dump(mode="json")
                for item in responses.examination_types(language)
            ],
            "neuralModels": [
                item.model_dump(mode="json")
                for item in responses.neural_models(language)
            ],
            "readyMadeTemplates": [
                item.model_dump(mode="json")
                for item in responses.ready_made_templates(language)
            ],
            "products": BillingCatalogResponseService.make(
                catalog, configuration, language
            ).model_dump(mode="json"),
        }
        result[f"{language.value}.json"] = (
            json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        )
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    directory = ROOT / "test/fixtures/development"
    directory.mkdir(parents=True, exist_ok=True)
    for name, content in documents().items():
        path = directory / name
        if args.check:
            if not path.exists() or path.read_text() != content:
                raise SystemExit(
                    "Development preview fixtures are stale: python3 test/scripts/preview_fixtures.py"
                )
        else:
            path.write_text(content)
    print("Development preview fixtures match the backend responses.")


if __name__ == "__main__":
    main()
