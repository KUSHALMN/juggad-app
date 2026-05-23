from pydantic import BaseModel, ConfigDict, field_validator
from datetime import datetime, timezone, timedelta

# IST timezone constant — used across all services
IST = timezone(timedelta(hours=5, minutes=30))


def now_ist() -> datetime:
    """Return current datetime in IST (Asia/Kolkata)."""
    return datetime.now(IST)


class CreateJobRequest(BaseModel):
    skill: str
    urgency: str
    scheduled_at: datetime | None = None
    lat: float
    lng: float
    description: str
    category: str

    model_config = ConfigDict(from_attributes=True)

    @field_validator("scheduled_at", mode="before")
    @classmethod
    def ensure_tz_aware(cls, v):
        """Ensure scheduled_at is timezone-aware. Assume IST if naive."""
        if v is None:
            return v
        if isinstance(v, str):
            v = datetime.fromisoformat(v)
        if v.tzinfo is None:
            v = v.replace(tzinfo=IST)
        return v

    @field_validator("description")
    @classmethod
    def validate_desc(cls, v):
        if len(v) < 10:
            raise ValueError("Description must be at least 10 chars")
        return v


class UserProfile(BaseModel):
    """User profile model for registration and updates."""
    display_name: str
    phone: str
    email: str | None = None
    lat: float | None = None
    lng: float | None = None

    model_config = ConfigDict(from_attributes=True)


class WorkerProfile(BaseModel):
    """Worker profile model for registration and updates."""
    name: str
    phone: str
    email: str | None = None
    skills: list[str] = []
    lat: float | None = None
    lng: float | None = None
    geo_hash_5: str | None = None
    approval_status: str = "PENDING"

    model_config = ConfigDict(from_attributes=True)


class ReviewRequest(BaseModel):
    """Review submission model."""
    workerId: str
    rating: float
    comment: str | None = None

    model_config = ConfigDict(from_attributes=True)

    @field_validator("rating")
    @classmethod
    def validate_rating(cls, v):
        if not (1.0 <= v <= 5.0):
            raise ValueError("Rating must be between 1.0 and 5.0")
        return v
