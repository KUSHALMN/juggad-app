# shared/logging.py
import json
import time


def log(service: str, function: str, action: str, **kwargs):
    """
    Structured JSON logging to stdout.
    Cloud Run → Cloud Logging auto-captures stdout as structured logs.
    Format: {"severity": "INFO", "service": "...", "function": "...", ...}
    """
    print(json.dumps({
        "severity": kwargs.pop("severity", "INFO"),
        "service": service,
        "function": function,
        "action": action,
        "timestamp": time.time(),
        **kwargs,
    }))
