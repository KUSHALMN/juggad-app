# shared/auth.py
import os
from fastapi import Request, HTTPException, Depends
from firebase_admin import auth as fb_auth
from shared.logging import log


# ─── 1. Public Firebase token (Flutter app users + workers) ──────

def verify_token(authorization_header: str) -> dict:
    """Verify Firebase Auth ID token from Authorization header value."""
    if not authorization_header.startswith("Bearer "):
        raise HTTPException(401, "Missing token")
    token = authorization_header.split(" ", 1)[1]
    try:
        decoded = fb_auth.verify_id_token(token)
        log("auth", "verify_token", "ok", uid=decoded["uid"])
        return decoded
    except Exception as e:
        log("auth", "verify_token", "fail", error=str(e), severity="WARNING")
        raise HTTPException(401, "Invalid token")


def get_current_user(request: Request) -> dict:
    """FastAPI dependency — extracts and verifies Firebase token. Returns full decoded dict."""
    return verify_token(request.headers.get("Authorization", ""))


def verify_firebase_token(request: Request) -> str:
    """
    FastAPI dependency — extracts Firebase ID token, verifies it,
    and returns ONLY the uid string.
    Usage: uid: str = Depends(verify_firebase_token)
    """
    decoded = verify_token(request.headers.get("Authorization", ""))
    return decoded["uid"]


# ─── 2. Google OIDC token (Pub/Sub push subscriptions) ──────────

def verify_pubsub_oidc(request: Request) -> None:
    """
    Pub/Sub push subscriptions attach a Google-signed OIDC JWT in
    the Authorization header. We verify the signature + audience
    to ensure only our GCP service account can trigger these endpoints.
    Called at the top of every /pubsub-push handler.
    """
    import google.auth.transport.requests
    import google.oauth2.id_token

    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        raise HTTPException(401, "Missing OIDC token")
    token = header.split(" ", 1)[1]
    # Audience = this service's own URL (Cloud Run assigns it)
    audience = str(request.url).split("?")[0]
    try:
        req = google.auth.transport.requests.Request()
        claims = google.oauth2.id_token.verify_oauth2_token(token, req, audience=audience)
        expected = os.getenv("GCP_SERVICE_ACCOUNT_EMAIL")
        if claims.get("email") != expected:
            raise ValueError(f"Unexpected issuer: {claims.get('email')}")
        log("auth", "verify_pubsub_oidc", "ok", email=claims["email"])
    except Exception as e:
        log("auth", "verify_pubsub_oidc", "fail", error=str(e), severity="WARNING")
        raise HTTPException(401, "Invalid OIDC token")


def verify_oidc_token(request: Request) -> None:
    """
    Verify OIDC identity token for internal service-to-service communication.
    The expected audience is configured via the INTERNAL_SERVICE_AUDIENCE env var.
    """
    import google.auth.transport.requests
    import google.oauth2.id_token

    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        raise HTTPException(401, "Missing OIDC token")
    token = header.split(" ", 1)[1]
    audience = os.getenv("INTERNAL_SERVICE_AUDIENCE")

    try:
        req = google.auth.transport.requests.Request()
        claims = google.oauth2.id_token.verify_oauth2_token(token, req, audience=audience)
        log("auth", "verify_oidc_token", "ok", email=claims.get("email"))
    except Exception as e:
        log("auth", "verify_oidc_token", "fail", error=str(e), severity="WARNING")
        raise HTTPException(401, "Invalid OIDC token")


# ─── 3. QStash HMAC signature (timeout / activate callbacks) ────

def verify_qstash_signature(request: Request, body: bytes) -> None:
    """
    QStash signs every outgoing request with an HMAC JWT in the
    Upstash-Signature header. The qstash SDK Receiver verifies this
    mathematically against both the current and next signing keys
    (supports key rotation without downtime).
    Called at the top of every QStash callback handler.
    """
    from qstash import Receiver
    receiver = Receiver(
        current_signing_key=os.getenv("QSTASH_CURRENT_SIGNING_KEY"),
        next_signing_key=os.getenv("QSTASH_NEXT_SIGNING_KEY"),
    )
    try:
        receiver.verify(
            signature=request.headers.get("Upstash-Signature", ""),
            body=body.decode(),
            url=str(request.url),
        )
        log("auth", "verify_qstash_signature", "ok")
    except Exception as e:
        log("auth", "verify_qstash_signature", "fail", error=str(e), severity="WARNING")
        raise HTTPException(401, "Invalid QStash signature")


# ─── 4. Admin (Firebase Custom Claims) ──────────────────────────

def verify_admin(request: Request) -> dict:
    """
    Decode the standard Firebase JWT and assert admin: True custom claim.
    Set the claim once on your founder account:
      firebase_admin.auth.set_custom_user_claims(YOUR_UID, {"admin": True})
    No static secret involved. Cryptographically bound to your Firebase account.
    """
    token_data = verify_token(request.headers.get("Authorization", ""))
    if not token_data.get("admin"):
        log("auth", "verify_admin", "denied", uid=token_data.get("uid"), severity="WARNING")
        raise HTTPException(403, "Admin access required")
    log("auth", "verify_admin", "granted", uid=token_data["uid"])
    return token_data
