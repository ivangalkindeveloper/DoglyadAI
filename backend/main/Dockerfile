# syntax=docker/dockerfile:1
FROM python:3.11-slim AS dependencies

# KenLM builds a native CPU extension. Keep the toolchain out of the runtime.
RUN apt-get update && apt-get install -y --no-install-recommends build-essential cmake git \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt /app/requirements.txt
RUN --mount=type=cache,id=doglyad-main-pip,target=/root/.cache/pip,sharing=locked \
    pip wheel --wheel-dir /wheels -r /app/requirements.txt

FROM python:3.11-slim AS models
RUN pip install --no-cache-dir huggingface-hub==0.36.2
WORKDIR /app
COPY app/service/speech/t_one_worker.py /app/app/service/speech/t_one_worker.py
COPY scripts/download_t_one_models.py /app/scripts/download_t_one_models.py
ENV HF_HUB_DISABLE_XET=1 PYTHONPATH=/app
RUN --mount=type=cache,id=doglyad-t-one-models,target=/cache \
    python scripts/download_t_one_models.py /cache/t_one \
    && mkdir -p /models/t_one \
    && cp /cache/t_one/model.onnx /cache/t_one/kenlm.bin /models/t_one/

FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*
RUN --mount=type=bind,from=dependencies,source=/wheels,target=/wheels \
    pip install --no-cache-dir --no-index /wheels/*.whl
COPY --from=models /models /app/models
RUN groupadd --gid 10001 doglyad \
    && useradd --uid 10001 --gid doglyad --no-create-home --shell /usr/sbin/nologin doglyad \
    && mkdir -p /app/logs \
    && chown doglyad:doglyad /app/logs

COPY app /app/app
COPY migrations /app/migrations
COPY alembic.ini /app/alembic.ini
# Configs ship inside the image: they are not secrets, and baking them in pins the
# config version to the code version instead of letting the two drift apart on a
# machine. Secrets are the opposite — mounted at run time, never built in, because
# the image itself is pushed to a registry.
COPY config /app/config
COPY mock /app/mock

ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

USER 10001:10001

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "*"]
