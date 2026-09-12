from __future__ import annotations

import logging

from fastapi import Response

from app.core.config import resolve_config_document

logger = logging.getLogger(__name__)


def config_document_response(name: str) -> Response:
    """Return a configuration document exactly as it was stored in the image."""
    logger.info("Config document served: %s", name)
    return Response(content=resolve_config_document(name), media_type="application/json")
