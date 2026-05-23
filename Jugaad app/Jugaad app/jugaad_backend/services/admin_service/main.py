from fastapi import FastAPI, Depends, HTTPException
from shared.auth import verify_firebase_token
from shared.firestore import db, FIRESTORE_TIMEOUT, FIRESTORE_RETRY
from firebase_admin import firestore as fs

app = FastAPI(title="Admin Service")


@app.get("/health")
def health():
    return {"status": "ok", "service": "admin_service"}


def verify_admin(uid: str = Depends(verify_firebase_token)):
    # Verify the user has an admin claim or exists in admins collection
    admin_doc = db.collection("admins").document(uid).get(
        timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
    )
    if not admin_doc.exists:
        raise HTTPException(status_code=403, detail="Not authorized as admin")
    return uid


@app.get("/admin/dashboard/stats")
def get_dashboard_stats(admin_uid: str = Depends(verify_admin)):
    # In production, use Firestore aggregation queries for faster counts
    users_count = len(list(db.collection("users").stream()))
    workers_count = len(list(db.collection("workers").stream()))
    
    pending_workers = [w.to_dict() for w in db.collection("workers").where("approval_status", "==", "PENDING").stream()]
    
    return {
        "usersCount": users_count,
        "workersCount": workers_count,
        "pendingWorkers": len(pending_workers),
        "pendingWorkerDetails": pending_workers
    }


@app.post("/admin/disputes/{booking_id}/resolve")
def resolve_dispute(booking_id: str, resolution: dict, admin_uid: str = Depends(verify_admin)):
    # Dispute resolution logic
    db.collection("bookings").document(booking_id).update({
        "status": "DISPUTE_RESOLVED",
        "resolution": resolution,
        "resolved_at": fs.SERVER_TIMESTAMP,
        "resolved_by": admin_uid,
    })
    return {"status": "success", "message": "Dispute resolved"}
