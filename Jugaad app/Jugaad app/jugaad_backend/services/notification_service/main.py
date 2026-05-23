# services/notification_service/main.py
"""
Notification Service — Multi-channel (FCM + Email + SMS)
FIX F: Write-first idempotency using atomic Firestore create.
Email via SMTP replaces SMS during dev/pilot phase.
"""
from fastapi import FastAPI, Request, HTTPException
from shared.auth import verify_pubsub_oidc, verify_oidc_token
from shared.firestore import db, FIRESTORE_TIMEOUT, FIRESTORE_RETRY
from shared.logging import log
from firebase_admin import firestore as fs, messaging
from google.api_core import exceptions as gcp_exc
from services.notification_service.email_service import send_email
from services.notification_service.email_templates import TEMPLATES
import json
import base64
import os
import httpx
import traceback
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("notification_service")

app = FastAPI()
EMAIL_ENABLED = os.getenv("EMAIL_ENABLED", "true").lower() == "true"


@app.middleware("http")
async def capture_raw_body(request: Request, call_next):
    request.state.raw_body = await request.body()
    response = await call_next(request)
    return response


@app.get("/health")
def health():
    return {"status": "ok", "service": "notification_service", "email_enabled": EMAIL_ENABLED}


# ─── Pub/Sub push (outbox events from other services) ──────

@app.post("/pubsub-push")
def pubsub_push(request: Request):
    """
    FIX F (CRITICAL): Idempotency is write-first, not read-then-write.
    Step 1: Attempt CREATE /notifications/{event_id} — only ONE succeeds
    Step 2: If AlreadyExists → skip immediately
    Step 3: If create succeeds → send FCM + Email
    """
    try:
        verify_pubsub_oidc(request)
        raw = request.state.raw_body
        envelope = json.loads(raw)
        message = json.loads(base64.b64decode(envelope["message"]["data"]))

        event_id = message.get("event_id")
        event_type = message.get("event_type")
        job_id = message.get("job_id")
        payload = message.get("payload", {})

        # FIX F: Atomic create BEFORE any network call.
        notif_ref = db.collection("notifications").document(event_id)
        try:
            notif_ref.create({
                "event_id": event_id,
                "event_type": event_type,
                "job_id": job_id,
                "status": "processing",
                "created_at": fs.SERVER_TIMESTAMP,
            })
        except gcp_exc.AlreadyExists:
            log("notification_service", "pubsub_push", "duplicate_skip",
                event_id=event_id, event_type=event_type)
            return {"status": "already_processed"}

        # Document created — we are the sole processor.
        try:
            _route_event(event_type, job_id, payload, event_id)
            notif_ref.update({"status": "sent", "sent_at": fs.SERVER_TIMESTAMP})
            log("notification_service", "pubsub_push", "sent",
                event_id=event_id, event_type=event_type)
        except Exception as e:
            notif_ref.update({
                "status": "failed", "error": str(e),
                "updated_at": fs.SERVER_TIMESTAMP,
            })
            log("notification_service", "pubsub_push", "send_failed",
                event_id=event_id, error=str(e), severity="ERROR")

        return {"status": "ok"}

    except HTTPException:
        raise
    except Exception as e:
        log("notification_service", "pubsub_push", "unexpected_error",
            severity="ERROR", error=str(e), trace=traceback.format_exc())
        raise HTTPException(500, "Internal server error")


# ─── Internal notify endpoint (direct HTTP from other services) ──

@app.post("/internal/notify")
def internal_notify(request: Request):
    """
    Direct notification endpoint for Pub/Sub push messages.
    Uses pre-read body from middleware.
    """
    try:
        verify_oidc_token(request)
        raw = request.state.raw_body
        payload = json.loads(raw)

        # Handle Pub/Sub envelope format
        if (
            isinstance(payload, dict)
            and "message" in payload
            and "data" in payload.get("message", {})
        ):
            data = json.loads(base64.b64decode(payload["message"]["data"]))
        else:
            data = payload

        event = data.get("event", data.get("event_type", ""))
        job_id = data.get("jobId", data.get("job_id", ""))
        event_id = data.get("event_id", f"{event}_{job_id}")

        # Idempotency check
        notif_ref = db.collection("notifications").document(event_id)
        try:
            notif_ref.create({
                "event_id": event_id,
                "event_type": event,
                "job_id": job_id,
                "status": "processing",
                "created_at": fs.SERVER_TIMESTAMP,
            })
        except gcp_exc.AlreadyExists:
            return {"status": "already_processed"}

        # Route email notifications
        _route_email(event, data)

        notif_ref.update({"status": "sent", "sent_at": fs.SERVER_TIMESTAMP})
        return {"status": "ok"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"internal_notify error: {e}\n{traceback.format_exc()}")
        raise HTTPException(500, str(e))


# ─── Event Router ───────────────────────────────────────────

def _route_event(event_type: str, job_id: str, payload: dict, event_id: str):
    """Route outbox event to FCM + Email channels."""

    if event_type == "JOB_BROADCASTED":
        for wid in payload.get("worker_ids", []):
            w = db.collection("workers").document(wid).get(
                timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
            ).to_dict() or {}
            _send_fcm(
                w.get("fcm_token"),
                "New job request!",
                f"{payload.get('skill', 'job')} nearby",
                {"type": "job_incoming", "job_id": job_id},
            )

    elif event_type == "JOB_ASSIGNED":
        job = db.collection("jobs").document(job_id).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        u = db.collection("users").document(job.get("user_id", "")).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        w = db.collection("workers").document(job.get("worker_id", "")).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        _send_fcm(
            u.get("fcm_token"), "Worker found!", "On the way",
            {"type": "job_assigned", "job_id": job_id},
        )
        # Email to customer
        _send_event_email("job_accepted", "customer", u.get("email"), {
            "customerName": u.get("display_name", "Customer"),
            "workerName": w.get("name", "Worker"),
            "jobId": job_id,
        })

    elif event_type == "JOB_ACK":
        job = db.collection("jobs").document(job_id).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        u = db.collection("users").document(job.get("user_id", "")).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        w = db.collection("workers").document(job.get("worker_id", "")).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        _send_fcm(
            u.get("fcm_token"), "Worker arrived", "At your location",
            {"type": "worker_arrived", "job_id": job_id},
        )
        _send_event_email("job_ack", "customer", u.get("email"), {
            "customerName": u.get("display_name", "Customer"),
            "workerName": w.get("name", "Worker"),
            "jobId": job_id,
        })

    elif event_type == "JOB_COMPLETED":
        job = db.collection("jobs").document(job_id).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        u = db.collection("users").document(job.get("user_id", "")).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        w = db.collection("workers").document(job.get("worker_id", "")).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        _send_fcm(
            u.get("fcm_token"), "Job done — time to pay", "Tap to pay",
            {"type": "job_completed", "job_id": job_id},
        )
        _send_event_email("job_completed", "customer", u.get("email"), {
            "customerName": u.get("display_name", "Customer"),
            "workerName": w.get("name", "Worker"),
            "jobId": job_id,
            "amount": job.get("payment_amount", 0),
        })

    elif event_type == "JOB_CANCELLED":
        job = db.collection("jobs").document(job_id).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        u = db.collection("users").document(job.get("user_id", "")).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        _send_fcm(
            u.get("fcm_token"), "Job cancelled", "Finding another worker...",
            {"type": "job_cancelled", "job_id": job_id},
        )

    elif event_type == "JOB_MANUAL_ASSIGN":
        w = db.collection("workers").document(
            payload.get("worker_id", "")).get(
                timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
            ).to_dict() or {}
        _send_fcm(
            w.get("fcm_token"), "New job assigned", "Open app",
            {"type": "job_manual_assign", "job_id": job_id},
        )

    elif event_type == "PAYMENT_CAPTURED":
        job = db.collection("jobs").document(job_id).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        u = db.collection("users").document(job.get("user_id", "")).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        w = db.collection("workers").document(job.get("worker_id", "")).get(
            timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
        ).to_dict() or {}
        _send_event_email("payment_success", "customer", u.get("email"), {
            "customerName": u.get("display_name", "Customer"),
            "workerName": w.get("name", "Worker"),
            "jobId": job_id,
            "amount": job.get("payment_amount", 0),
        })
        _send_event_email("payment_success", "worker", w.get("email"), {
            "workerName": w.get("name", "Worker"),
            "jobId": job_id,
            "amount": job.get("payment_amount", 0),
        })

    else:
        log("notification_service", "_route_event", "unknown_type",
            event_type=event_type, severity="WARNING")


# ─── Email routing for /internal/notify payloads ────────────

def _route_email(event: str, data: dict):
    """Route direct JSON payloads to email templates."""
    templates = TEMPLATES.get(event)
    if not templates:
        logger.warning(f"No email template for event: {event}")
        return

    # Send to customer
    if "customer" in templates and data.get("customerEmail"):
        _send_event_email(event, "customer", data["customerEmail"], data)

    # Send to worker
    if "worker" in templates and data.get("workerEmail"):
        _send_event_email(event, "worker", data["workerEmail"], data)


def _send_event_email(event: str, recipient_type: str, email: str | None, data: dict):
    """Look up template and send email."""
    if not EMAIL_ENABLED or not email:
        return
    templates = TEMPLATES.get(event)
    if not templates or recipient_type not in templates:
        return
    try:
        subject, html_body = templates[recipient_type](data)
        send_email(email, subject, html_body)
    except Exception as e:
        logger.error(f"Email send error [{event}→{email}]: {e}")


# ─── FCM Push ───────────────────────────────────────────────

def _send_fcm(token: str | None, title: str, body: str, data: dict):
    if not token:
        log("notification_service", "_send_fcm", "no_token", title=title)
        return
    try:
        msg = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in data.items()},
            token=token,
            android=messaging.AndroidConfig(priority="high"),
        )
        resp = messaging.send(msg)
        log("notification_service", "_send_fcm", "sent", message_id=resp)
    except Exception as e:
        log("notification_service", "_send_fcm", "failed",
            error=str(e), severity="WARNING")



