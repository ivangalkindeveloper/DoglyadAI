FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
RUN groupadd --gid 10001 doglyad \
    && useradd --uid 10001 --gid doglyad --no-create-home --shell /usr/sbin/nologin doglyad \
    && mkdir -p /app/logs \
    && chown doglyad:doglyad /app/logs

COPY app /app/app
# Configs ship inside the image: they are not secrets, and baking them in pins the
# config version to the code version instead of letting the two drift apart on a
# machine. Secrets are the opposite — mounted at run time, never built in, because
# the image itself is pushed to a registry.
COPY config /app/config

ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

USER 10001:10001

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "*"]
