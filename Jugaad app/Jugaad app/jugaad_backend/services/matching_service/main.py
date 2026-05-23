from fastapi import FastAPI, Request, HTTPException
from shared.firestore import db, FIRESTORE_TIMEOUT, FIRESTORE_RETRY
from shared.geo import neighbors_for_radius, haversine_km
from shared.auth import verify_pubsub_oidc
from shared.logging import log
from firebase_admin import firestore as fs
import json
import base64
import traceback

app = FastAPI(title="Matching Service")


@app.get("/health")
def health():
    return {"status": "ok", "service": "matching_service"}


@app.middleware("http")
async def capture_raw_body(request: Request, call_next):
    request.state.raw_body = await request.body()
    response = await call_next(request)
    return response


@app.post("/pubsub-push")
def match_workers(request: Request):
    """
    Receives JOB_BROADCASTED events via Pub/Sub push.
    Searches 9 geohash cells for available workers with matching skills.
    Returns matched worker IDs to the job document.
    """
    try:
        verify_pubsub_oidc(request)
        raw = request.state.raw_body
        envelope = json.loads(raw)
        message = json.loads(base64.b64decode(envelope["message"]["data"]))

        job_id = message.get("job_id")
        payload = message.get("payload", {})
        skill = payload.get("skill", "")
        lat = payload.get("lat", 0)
        lng = payload.get("lng", 0)
        radius_km = payload.get("radius_km", 5)

        if not job_id or not skill:
            log("matching_service", "match_workers", "missing_fields",
                severity="WARNING", job_id=job_id)
            return {"status": "skipped", "reason": "missing job_id or skill"}

        # Get 9 geohash cells (center + 8 neighbors) for proximity search
        geohashes = neighbors_for_radius(lat, lng, precision=5)

        matched_workers = []
        for gh in geohashes:
            # Query workers in this geohash cell who are:
            # 1. APPROVED  2. ONLINE  3. Have the required skill 4. In this geohash
            workers_query = (
                db.collection("workers")
                .where("geo_hash_5", "==", gh)
                .where("approval_status", "==", "APPROVED")
                .where("status", "==", "ONLINE")
                .where("skills", "array_contains", skill)
            )
            for doc in workers_query.stream():
                worker = doc.to_dict()
                worker_id = doc.id

                # Calculate exact distance
                w_lat = worker.get("lat", 0)
                w_lng = worker.get("lng", 0)
                distance = haversine_km(lat, lng, w_lat, w_lng)

                if distance <= radius_km:
                    matched_workers.append({
                        "worker_id": worker_id,
                        "distance_km": round(distance, 2),
                        "name": worker.get("name", ""),
                        "rating": worker.get("rating", 0),
                    })

        # Sort by distance (nearest first)
        matched_workers.sort(key=lambda w: w["distance_km"])

        # Update the job document with matched workers
        worker_ids = [w["worker_id"] for w in matched_workers]
        db.collection("jobs").document(job_id).update({
            "matched_workers": worker_ids,
            "match_count": len(worker_ids),
            "match_details": matched_workers[:10],  # Store top 10 details
            "matched_at": fs.SERVER_TIMESTAMP,
            "status": "MATCHED" if worker_ids else "NO_MATCH",
        })

        log("matching_service", "match_workers", "complete",
            job_id=job_id, skill=skill, matched=len(worker_ids))

        return {
            "status": "ok",
            "job_id": job_id,
            "matched_workers": len(worker_ids),
        }

    except HTTPException:
        raise
    except Exception as e:
        log("matching_service", "match_workers", "unexpected_error",
            severity="ERROR", error=str(e), trace=traceback.format_exc())
        raise HTTPException(500, "Internal server error")
