FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir aiosmtpd==1.4.6
COPY receiver.py /app/receiver.py
CMD ["python", "/app/receiver.py"]
