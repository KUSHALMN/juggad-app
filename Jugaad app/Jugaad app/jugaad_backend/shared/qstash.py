# shared/qstash.py
"""
QStash is an HTTP-based task queue. You call enqueue_task() with a
target URL and a JSON body. QStash delivers an HTTP POST to that URL
after delay_seconds, with HMAC signing.

KEY POINT (FIX A): The target URL must be publicly reachable.
Cloud Run services have internal ingress only. Therefore all QStash
callback URLs MUST point to the API Gateway /internal/* paths, NOT
directly to Cloud Run service URLs.

Example:
  enqueue_task(
    url=os.getenv("JOB_SERVICE_TIMEOUT_URL"),  # API Gateway URL
    body={"job_id": job_id, "expected_version": new_version},
    delay_seconds=125
  )
"""
import httpx
import json
import os
from shared.logging import log

QSTASH_TOKEN = os.getenv("QSTASH_TOKEN")
QSTASH_BASE = "https://qstash.upstash.io/v2/publish"


def enqueue_task(url: str, body: dict, delay_seconds: int = 0) -> str:
    """
    Publishes a delayed task. QStash retries failed deliveries 3x
    with exponential backoff by default.
    Returns the QStash message ID on success.
    Raises httpx.HTTPStatusError on failure — caller must handle.
    """
    headers = {
        "Authorization": f"Bearer {QSTASH_TOKEN}",
        "Content-Type": "application/json",
        "Upstash-Delay": f"{delay_seconds}s",
        "Upstash-Retries": "3",
    }
    resp = httpx.post(
        f"{QSTASH_BASE}/{url}",
        headers=headers,
        content=json.dumps(body),
        timeout=10,
    )
    resp.raise_for_status()
    message_id = resp.json().get("messageId", "unknown")
    log("qstash", "enqueue_task", "published",
        url=url, delay_seconds=delay_seconds, message_id=message_id)
    return message_id
