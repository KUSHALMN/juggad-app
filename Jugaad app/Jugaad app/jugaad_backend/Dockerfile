FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all shared utilities + all services into the image.
# The SERVICE_NAME env var (set at deploy time) selects which one runs.
COPY shared/ ./shared/
COPY services/ ./services/

ENV PORT=8080

# Gunicorn dynamically imports the correct service module via SERVICE_NAME env var
CMD gunicorn "services.${SERVICE_NAME}.main:app" -w 1 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:${PORT} --timeout 60 --access-logfile -
