from fastapi import FastAPI, HTTPException, Depends, Request
from pydantic import BaseModel
import os
from shared.firestore import db, FIRESTORE_TIMEOUT, FIRESTORE_RETRY
from shared.auth import verify_firebase_token
from shared.models import now_ist
from firebase_admin import firestore as fs

from collections import defaultdict
import time

app = FastAPI(title="Auth Service")

# In-memory rate limiter: maps key to list of request timestamps
rate_limit_store = defaultdict(list)

def is_rate_limited(key: str, limit: int = 5, window: int = 60) -> bool:
    now = time.time()
    rate_limit_store[key] = [t for t in rate_limit_store[key] if now - t < window]
    if len(rate_limit_store[key]) >= limit:
        return True
    rate_limit_store[key].append(now)
    return False


class LoginResponse(BaseModel):
    message: str
    uid: str
    role: str


class SendOtpRequest(BaseModel):
    phone: str


@app.get("/health")
def health():
    return {"status": "ok", "service": "auth_service"}


@app.post("/v1/auth/send-otp")
def send_otp(request: Request, req: SendOtpRequest):
    client_ip = request.client.host if request.client else "unknown"
    if is_rate_limited(client_ip, limit=5, window=60) or is_rate_limited(req.phone, limit=5, window=60):
        raise HTTPException(status_code=429, detail="Too many OTP requests. Please try again later.")
    return {"message": "OTP sent successfully"}


@app.post("/v1/auth/login", response_model=LoginResponse)
def login(request: Request, uid: str = Depends(verify_firebase_token)):
    """
    Client handles Firebase Phone Auth (OTP) natively.
    Once successful, the client sends the Firebase ID token here.
    We check if the user/worker profile exists.
    """
    client_ip = request.client.host if request.client else "unknown"
    if is_rate_limited(client_ip, limit=5, window=60):
        raise HTTPException(status_code=429, detail="Too many login attempts. Please try again later.")
    users = db.collection("users").document(uid).get(
        timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
    )
    workers = db.collection("workers").document(uid).get(
        timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
    )
    
    role = "none"
    if users.exists:
        role = "user"
    elif workers.exists:
        role = "worker"
    else:
        # First time login, client must redirect to onboarding
        role = "new"
    
    return LoginResponse(message="Login successful", uid=uid, role=role)


@app.post("/v1/auth/register-user")
def register_user(profile: dict, uid: str = Depends(verify_firebase_token)):
    profile["created_at"] = fs.SERVER_TIMESTAMP
    profile["updated_at"] = fs.SERVER_TIMESTAMP
    db.collection("users").document(uid).set(profile)
    return {"message": "User registered", "uid": uid, "role": "user"}


@app.post("/v1/auth/register-worker")
def register_worker(profile: dict, uid: str = Depends(verify_firebase_token)):
    profile["approval_status"] = "PENDING"
    profile["created_at"] = fs.SERVER_TIMESTAMP
    profile["updated_at"] = fs.SERVER_TIMESTAMP
    db.collection("workers").document(uid).set(profile)
    return {"message": "Worker registered", "uid": uid, "role": "worker"}
