from fastapi import FastAPI, Request, HTTPException, Depends
from shared.auth import verify_token, verify_firebase_token
from shared.firestore import db, FIRESTORE_TIMEOUT, FIRESTORE_RETRY
from shared.logging import log
from firebase_admin import firestore as fs
from google.cloud.firestore_v1 import transactional
from pydantic import BaseModel
import uuid


app = FastAPI(title="Booking Service")


class AcceptBookingRequest(BaseModel):
    """Payload for accepting a booking."""
    notes: str | None = None


@app.get("/health")
def health():
    return {"status": "ok", "service": "booking_service"}


@app.post("/v1/bookings/{booking_id}/accept")
def accept_booking(booking_id: str, uid: str = Depends(verify_firebase_token)):
    """
    Worker accepts a booking. Uses Firestore transaction for
    atomic read-then-write to prevent double-accept race condition.
    """
    worker_id = uid

    booking_ref = db.collection("bookings").document(booking_id)
    
    @transactional
    def _accept_tx(tx):
        snap = booking_ref.get(transaction=tx)
        if not snap.exists:
            raise HTTPException(404, "Booking not found")
        data = snap.to_dict()
        if data.get("status") != "PENDING":
            raise HTTPException(400, "Booking no longer available")
        
        tx.update(booking_ref, {
            "status": "ACCEPTED",
            "worker_id": worker_id,
            "acceptedAt": fs.SERVER_TIMESTAMP,
            "updatedAt": fs.SERVER_TIMESTAMP,
        })
        return True

    _accept_tx(db.transaction())
    log("booking_service", "accept_booking", "accepted",
        booking_id=booking_id, worker_id=worker_id)
    return {"status": "accepted", "booking_id": booking_id}
