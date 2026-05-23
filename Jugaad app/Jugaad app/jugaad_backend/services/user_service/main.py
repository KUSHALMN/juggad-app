from fastapi import FastAPI, Depends, HTTPException, Request
from shared.auth import verify_firebase_token
from shared.models import UserProfile
from shared.firestore import db, FIRESTORE_TIMEOUT, FIRESTORE_RETRY
from firebase_admin import firestore as fs

app = FastAPI(title="User Service")


@app.get("/health")
def health():
    return {"status": "ok", "service": "user_service"}


@app.get("/users/me")
def get_profile(uid: str = Depends(verify_firebase_token)):
    doc = db.collection("users").document(uid).get(
        timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
    )
    if not doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
    return doc.to_dict()


@app.put("/users/me")
def update_profile(profile: dict, uid: str = Depends(verify_firebase_token)):
    profile["updated_at"] = fs.SERVER_TIMESTAMP
    db.collection("users").document(uid).set(profile, merge=True)
    return {"status": "success", "message": "Profile updated"}


@app.post("/users/me/address")
def add_address(address: dict, uid: str = Depends(verify_firebase_token)):
    address["created_at"] = fs.SERVER_TIMESTAMP
    db.collection("users").document(uid).collection("addresses").add(address)
    return {"status": "success", "message": "Address added"}

@app.post("/v1/users/{user_id}/fcm-token")
def user_fcm_token(user_id: str, payload: dict, uid: str = Depends(verify_firebase_token)):
    if uid != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    token = payload.get("token")
    if token:
        db.collection("users").document(user_id).update({
            "fcm_token": token,
            "fcm_updated_at": fs.SERVER_TIMESTAMP
        })
    return {"status": "success"}
