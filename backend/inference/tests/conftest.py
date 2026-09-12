from __future__ import annotations

import os

# `app.core.variables` instantiates `Variables()` at import time, which requires
# SERVED_MODEL_ID to be set (there is no default and no env_file is configured).
# Provide it so the app package can be imported under pytest without a real
# `backend/inference/secrets/.env` present.
os.environ.setdefault("SERVED_MODEL_ID", "example/served-model")
