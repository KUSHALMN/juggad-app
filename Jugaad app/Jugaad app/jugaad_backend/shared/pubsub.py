"""
shared/pubsub.py — Pub/Sub abstraction layer.

NOTE: Google Cloud Pub/Sub is OPTIONAL. If google-cloud-pubsub is not
installed or credentials are not available, this module provides no-op
stubs that log warnings instead of crashing the entire backend.

For local dev / non-GCP deployments, event routing goes through:
  - QStash (scheduled task delivery)
  - Direct HTTP calls between services
  - Firestore outbox pattern (polled by outbox_publisher)
"""
import os
import json
from shared.logging import log

project_id = os.getenv("PUBSUB_PROJECT_ID", os.getenv("GOOGLE_CLOUD_PROJECT", ""))

# Lazy-init PubSub clients — only create when actually called
_publisher = None
_subscriber = None
_pubsub_available = None

PUBSUB_TIMEOUT = float(os.getenv("PUBSUB_TIMEOUT", "60"))


def _ensure_pubsub():
    """Lazy-initialize PubSub clients. Returns True if available."""
    global _publisher, _subscriber, _pubsub_available
    if _pubsub_available is not None:
        return _pubsub_available
    try:
        from google.cloud import pubsub_v1
        _publisher = pubsub_v1.PublisherClient()
        _subscriber = pubsub_v1.SubscriberClient()
        _pubsub_available = True
        log("pubsub", "_ensure_pubsub", "initialized")
    except Exception as e:
        _pubsub_available = False
        log("pubsub", "_ensure_pubsub", "unavailable",
            severity="WARNING", error=str(e))
    return _pubsub_available


def publish_event(topic_name: str, event_type: str, job_id: str,
                  version: int, payload: dict, event_id: str = "") -> str:
    """Publish event to Pub/Sub topic. No-ops if PubSub unavailable."""
    if not _ensure_pubsub():
        log("pubsub", "publish", "skipped_no_pubsub",
            severity="WARNING", topic=topic_name, event_type=event_type)
        return "pubsub_unavailable"

    topic_path = _publisher.topic_path(project_id, topic_name)
    data = json.dumps({
        "event_type": event_type,
        "event_id": event_id,
        "job_id": job_id,
        "version": version,
        "payload": payload,
    }).encode("utf-8")
    try:
        future = _publisher.publish(topic_path, data, ordering_key=job_id)
        msg_id = future.result(timeout=PUBSUB_TIMEOUT)
        log("pubsub", "publish", "ok", msg_id=msg_id)
        return msg_id
    except Exception as e:
        log("pubsub", "publish", "fail", error=str(e))
        raise


def subscribe_topic(subscription_name: str, callback):
    """Subscribe to a Pub/Sub topic. No-ops if PubSub unavailable."""
    if not _ensure_pubsub():
        log("pubsub", "subscribe", "skipped_no_pubsub",
            severity="WARNING", subscription=subscription_name)
        return None

    subscription_path = _subscriber.subscription_path(project_id, subscription_name)

    def wrapped(message):
        try:
            callback(message)
            message.ack()
        except Exception as e:
            log("pubsub", "subscribe", "fail", error=str(e))
            message.nack()
    try:
        future = _subscriber.subscribe(subscription_path, callback=wrapped)
        return future
    except Exception as e:
        log("pubsub", "subscribe_start", "fail", error=str(e))
        raise
