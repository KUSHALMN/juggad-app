from fastapi import FastAPI, Depends, HTTPException, Request
from shared.auth import verify_firebase_token
from shared.firestore import db, FIRESTORE_TIMEOUT, FIRESTORE_RETRY
from shared.models import now_ist
from shared.logging import log
from shared.geo import haversine_km
from firebase_admin import firestore as fs
import pygeohash as pgh

app = FastAPI(title="Worker Service")


@app.get("/health")
def health():
    return {"status": "ok", "service": "worker_service"}


@app.get("/workers/me")
def get_worker_profile(uid: str = Depends(verify_firebase_token)):
    doc = db.collection("workers").document(uid).get(
        timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
    )
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Worker not found")
    return doc.to_dict()


@app.put("/workers/me")
def update_worker_profile(profile: dict, uid: str = Depends(verify_firebase_token)):
    if "lat" in profile and "lng" in profile:
        profile["geo_hash_5"] = pgh.encode(profile["lat"], profile["lng"], precision=5)
    
    profile["updated_at"] = fs.SERVER_TIMESTAMP
    db.collection("workers").document(uid).set(profile, merge=True)
    return {"status": "success", "message": "Worker profile updated"}


@app.post("/workers/me/id-doc")
def upload_id_doc(doc_url: str, uid: str = Depends(verify_firebase_token)):
    db.collection("workers").document(uid).update({
        "id_doc_url": doc_url,
        "approval_status": "PENDING",
        "updated_at": fs.SERVER_TIMESTAMP,
    })
    return {"status": "success", "message": "ID Document submitted for review"}

@app.post("/v1/workers/{worker_id}/heartbeat")
def worker_heartbeat(worker_id: str, payload: dict, uid: str = Depends(verify_firebase_token)):
    if uid != worker_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    lat = payload.get("lat")
    lng = payload.get("lng")
    updates = {
        "last_heartbeat": fs.SERVER_TIMESTAMP,
        "status": "ONLINE"
    }
    if lat is not None and lng is not None:
        # Perform GPS Velocity Fraud check
        worker_ref = db.collection("workers").document(worker_id)
        doc = worker_ref.get()
        if doc.exists:
            prev_data = doc.to_dict()
            prev_lat = prev_data.get("lat")
            prev_lng = prev_data.get("lng")
            prev_time = prev_data.get("last_heartbeat")
            
            if prev_lat is not None and prev_lng is not None and prev_time is not None:
                dist = haversine_km(prev_lat, prev_lng, lat, lng)
                time_diff = (now_ist() - prev_time).total_seconds()
                if time_diff > 2:  # Avoid division by zero / extreme jitter
                    speed = (dist / time_diff) * 3600.0
                    if speed > 150.0:  # Exceeds impossible threshold of 150 km/h
                        log("worker_service", "heartbeat", "gps_fraud_detected", worker_id=worker_id, speed_kmh=speed, severity="WARNING")
                        raise HTTPException(status_code=400, detail="GPS velocity physically impossible")
        
        updates["lat"] = lat
        updates["lng"] = lng
        updates["geo_hash_5"] = pgh.encode(lat, lng, precision=5)
        
    db.collection("workers").document(worker_id).update(updates)
    return {"status": "success"}

@app.post("/v1/workers/{worker_id}/fcm-token")
def worker_fcm_token(worker_id: str, payload: dict, uid: str = Depends(verify_firebase_token)):
    if uid != worker_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    token = payload.get("token")
    if token:
        db.collection("workers").document(worker_id).update({
            "fcm_token": token,
            "fcm_updated_at": fs.SERVER_TIMESTAMP
        })
    return {"status": "success"}
