from fastapi import FastAPI, Depends, HTTPException
from shared.auth import verify_firebase_token
from shared.firestore import db, FIRESTORE_TIMEOUT, FIRESTORE_RETRY
from shared.models import ReviewRequest
from google.cloud.firestore_v1 import transactional
from firebase_admin import firestore as fs

app = FastAPI(title="Review Service")


@app.get("/health")
def health():
    return {"status": "ok", "service": "review_service"}


@app.post("/reviews")
def submit_review(review: ReviewRequest, uid: str = Depends(verify_firebase_token)):
    """
    Submit a review for a worker. Uses Firestore transaction to atomically
    add the review and update the worker's aggregate rating.
    """
    worker_id = review.workerId
    rating = review.rating

    # We use a transaction directly here
    transaction = db.transaction()
    worker_ref = db.collection("workers").document(worker_id)
    
    @transactional
    def execute_review(transaction):
        # 1. Read phase (must occur before any writes)
        snapshot = worker_ref.get(transaction=transaction)
        
        # 2. Write phase: Add review
        new_review_ref = db.collection("reviews").document()
        transaction.set(new_review_ref, {
            "workerId": worker_id,
            "userId": uid,
            "rating": rating,
            "comment": review.comment,
            "created_at": fs.SERVER_TIMESTAMP,
        })
        
        # 3. Write phase: Update worker aggregate rating
        if snapshot.exists:
            data = snapshot.to_dict()
            current_rating = data.get("rating", 0)
            review_count = data.get("reviewCount", 0)
            
            new_count = review_count + 1
            new_rating = ((current_rating * review_count) + rating) / new_count
            
            transaction.update(worker_ref, {
                "rating": round(new_rating, 2),
                "reviewCount": new_count,
                "updated_at": fs.SERVER_TIMESTAMP,
            })
            
    execute_review(transaction)
    return {"status": "success", "message": "Review submitted and aggregate updated"}
