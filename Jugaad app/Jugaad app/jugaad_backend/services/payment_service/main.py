from fastapi import FastAPI, Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from shared.firestore import db, FIRESTORE_TIMEOUT, FIRESTORE_RETRY
from shared.logging import log
from shared.models import now_ist
from firebase_admin import firestore as fs
import hmac
import hashlib
import os
import json
import traceback
app = FastAPI(title="Payment Service")
WHOOK = os.getenv("RAZORPAY_WEBHOOK_SECRET", "")


@app.get("/health")
def health():
    return {"status": "ok", "service": "payment_service"}


@app.post("/v1/webhooks/razorpay")
async def razorpay_webhook(request: Request):
    """
    Razorpay sends payment.captured / payment.failed events here.
    Verified via HMAC-SHA256 signature.
    """
    body_bytes = await request.body()
    sig = request.headers.get("X-Razorpay-Signature", "")

    if not WHOOK:
        log("payment_service", "webhook", "no_secret_configured", severity="ERROR")
        raise HTTPException(500, "Webhook secret not configured")

    # L1-04 FIX: hmac.new() is Python 2 — use hmac.new() correctly (it IS valid in Python 3 too as hmac.new)
    expected = hmac.new(WHOOK.encode(), body_bytes, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, sig):
        log("payment_service", "webhook", "invalid_signature", severity="WARNING")
        raise HTTPException(400, "Invalid signature")

    # Process the webhook event
    try:
        event = json.loads(body_bytes)
        event_type = event.get("event", "")
        payment_entity = event.get("payload", {}).get("payment", {}).get("entity", {})
        order_id = payment_entity.get("order_id", "")
        payment_id = payment_entity.get("id", "")
        amount = payment_entity.get("amount", 0)  # in paise

        if event_type == "payment.captured":
            # Record payment in Firestore
            db.collection("payments").document(payment_id).set({
                "payment_id": payment_id,
                "order_id": order_id,
                "amount_paise": amount,
                "amount_rupees": amount / 100,
                "status": "CAPTURED",
                "event_type": event_type,
                "created_at": fs.SERVER_TIMESTAMP,
                "raw_event": event,
            })
            log("payment_service", "webhook", "payment_captured",
                payment_id=payment_id, order_id=order_id, amount=amount)

        elif event_type == "payment.failed":
            db.collection("payments").document(payment_id).set({
                "payment_id": payment_id,
                "order_id": order_id,
                "amount_paise": amount,
                "status": "FAILED",
                "event_type": event_type,
                "created_at": fs.SERVER_TIMESTAMP,
            })
            log("payment_service", "webhook", "payment_failed",
                payment_id=payment_id, severity="WARNING")

        else:
            log("payment_service", "webhook", "unknown_event",
                event_type=event_type, severity="WARNING")

        return {"status": "processed"}

    except json.JSONDecodeError:
        raise HTTPException(400, "Invalid JSON body")
    except Exception as e:
        log("payment_service", "webhook", "processing_error",
            severity="ERROR", error=str(e), trace=traceback.format_exc())
        raise HTTPException(500, "Internal error")
