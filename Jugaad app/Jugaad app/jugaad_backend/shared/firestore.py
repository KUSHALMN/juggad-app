# shared/firestore.py
import os
import firebase_admin
from firebase_admin import credentials, firestore
from google.api_core import retry as api_retry
from google.api_core import exceptions as api_exceptions
from shared.logging import log

_app = None

# ─── Timeout & Retry Configuration ────────────────────────────
# "context deadline exceeded" fix: explicit timeout + retry policy
FIRESTORE_TIMEOUT = float(os.getenv("FIRESTORE_TIMEOUT", "60"))  # seconds

# Custom retry: covers transient gRPC errors that cause deadline exceeded
FIRESTORE_RETRY = api_retry.Retry(
    initial=0.5,           # first retry after 0.5s
    maximum=30.0,          # max backoff 30s
    multiplier=2.0,        # exponential backoff
    timeout=FIRESTORE_TIMEOUT,
    predicate=api_retry.if_exception_type(
        api_exceptions.DeadlineExceeded,
        api_exceptions.ServiceUnavailable,
        api_exceptions.InternalServerError,
        api_exceptions.Aborted,
        api_exceptions.Unknown,
    ),
)


def _init():
    global _app
    if _app is None:
        cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")

        # Also set GOOGLE_APPLICATION_CREDENTIALS for google-cloud libs
        # that don't go through firebase_admin (e.g. pubsub, logging)
        if cred_path and not os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = cred_path

        cred = credentials.Certificate(cred_path)
        _app = firebase_admin.initialize_app(cred)
        log("firestore", "_init", "initialized",
            project=os.getenv("GOOGLE_CLOUD_PROJECT"),
            timeout=FIRESTORE_TIMEOUT)


_init()
db = firestore.client()  # SYNC client — used with standard def routes


def get_job(job_id: str) -> dict | None:
    """Read a single job document. Returns None if not found."""
    snap = db.collection("jobs").document(job_id).get(
        timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
    )
    return snap.to_dict() if snap.exists else None


def get_worker(worker_id: str) -> dict | None:
    """Read a single worker document. Returns None if not found."""
    snap = db.collection("workers").document(worker_id).get(
        timeout=FIRESTORE_TIMEOUT, retry=FIRESTORE_RETRY
    )
    return snap.to_dict() if snap.exists else None
