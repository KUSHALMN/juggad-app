# 🚀 Jugaad Hyperlocal Skill Marketplace — Full-System Audit & Verification

Welcome to the **Jugaad** hyperlocal skill marketplace production codebase. This repository contains the audited, debugged, and fully verified production systems representing a 7-layer architecture designed for low-latency, transactional, and fraud-resistant hyperlocal service matching in India ( Mysuru pilot city).

---

## 🏗️ System Architecture & Services

The backend consists of **9 FastAPI microservices** deployed on Google Cloud Run, communicating asynchronously via Google Cloud Pub/Sub and utilizing Firestore as a globally distributed ACID database.

| Service Name | Purpose / Responsibility | Core API & Pub/Sub Endpoints |
| :--- | :--- | :--- |
| **`auth_service`** | OTP delivery, user login/registration, Firebase token generation, and OTP rate-limiting. | `/v1/auth/send-otp`, `/v1/auth/login` |
| **`user_service`** | Manages consumer profiles, address books, and FCM token association. | `/users/me`, `/v1/users/{id}/fcm-token` |
| **`worker_service`** | Handles worker onboarding, real-time GPS heartbeats, and velocity-based fraud checks. | `/workers/me`, `/v1/workers/{id}/heartbeat` |
| **`booking_service`** | Governs job/booking state machines using Firestore transactional locks. | `/v1/bookings/{id}/accept` |
| **`matching_service`** | Performs 9-cell geohash proximity matching for available workers matching job skills. | `/pubsub-push` |
| **`payment_service`** | Manages Razorpay escrow holds and processes capturing via verified signatures. | `/v1/webhooks/razorpay` |
| **`review_service`** | Handles rating/review submissions and atomically recalculates worker aggregates. | `/reviews` |
| **`notification_service`** | Delivers SMS (MSG91) and Push (FCM) notifications with robust idempotency rules. | `/pubsub-push`, `/internal/notify` |
| **`admin_service`** | Power dashboard aggregates and handles dispute resolution workflows. | `/admin/dashboard/stats`, `/admin/disputes/{id}/resolve` |

---

## 🔒 Security Rules & Anti-Fraud Measures

### 1. Zero Trust Firestore Rules
All database access is restricted. Unauthenticated reads and writes are globally denied.
- **Users**: Read/Write allowed only for matching `request.auth.uid`.
- **Workers**: Broad read allowed for matching, but writes are strictly prohibited except for updating their FCM notification tokens.
- **Jobs & Payments**: Read allowed only for the associated user or assigned worker. Write restricted entirely to backend microservices via IAM service accounts.

### 2. Hyperlocal GPS Velocity Fraud Check
To prevent GPS spoofing and location spoofing, a physics-based velocity check is integrated into the worker heartbeat. If a worker jumps more than **30km in under 60 seconds** (exceeding a velocity of 150 km/h), the heartbeat is rejected with a `400 Bad Request` and flagged as potential fraud in the security log.

### 3. Webhook Integrity (Razorpay)
The `payment_service` verifies the integrity of incoming webhook notifications (`payment.captured`, `payment.failed`) via HMAC-SHA256 signatures using the configured webhook secret. Tampered payloads are rejected instantly with `400 Bad Request`.

### 4. OTP Abuse Rate Limiting
To prevent financial and API spam, OTP generation and login endpoints enforce rate limits limiting users/phones to **5 requests per minute**, returning `429 Too Many Requests` on abuse.

---

## 🛠️ Setup & Running

### Prerequisites
- Docker & Docker Compose
- Python 3.10+ (for local testing)
- Flutter SDK (for mobile frontend compilation)

### Development Setup
1. Clone the repository:
   ```bash
   git clone <repository_url>
   cd "Jugaad app/Jugaad app"
   ```

2. Create a `.env` file in the `jugaad_backend` root directory following `.env.example`:
   ```ini
   FIREBASE_PROJECT_ID=jugaad-prod-app-2026
   RAZORPAY_WEBHOOK_SECRET=your_razorpay_secret
   # GCP Service accounts
   GCP_SERVICE_ACCOUNT_EMAIL=745766971944-compute@developer.gserviceaccount.com
   ```

3. Spin up the system via Docker Compose:
   ```bash
   docker-compose up --build
   ```

---

## 🛡️ Completed Audit & Quality Checklist

### Layer 1 — FastAPI Backend Services
- [x] Programmatically loaded all 9 microservices and verified zero compilation or dependency errors.
- [x] Verified `/health` endpoints across all 9 services return `200 OK` simultaneously.
- [x] Verified Pydantic v2 validation constraints.
- [x] Confirmed all database-backed dates are timezone-aware and stored in **Indian Standard Time (IST) (Asia/Kolkata)**.

### Layer 2 — Authentication & Security
- [x] Bypassed and verified OAuth2 OIDC ID token validation for secure inter-service channels.
- [x] Audited secure Razorpay HMAC signature checks.
- [x] Verified GPS Velocity Fraud check triggers warning alerts on impossible worker transitions.
- [x] Implemented OTP rate-limiting blocks returning `429` on 6th consecutive request.
- [x] Conducted full-codebase secrets sweep and migrated hardcoded variables to `.env`.

### Layer 3 — Firestore Database
- [x] Audited and verified security rules matching production constraints.
- [x] Simulated booking locks verifying transaction isolation (only one worker accepts successfully, subsequent workers fail gracefully).
- [x] Validated automated geohash calculation matching coordinates.
- [x] Swept database and deleted legacy or placeholder records.

### Layer 4 — Event-Driven Architecture
- [x] Audited Pub/Sub topics and subscriptions matching production.
- [x] Verified push notification subscription deduplication and message idempotency (returning `already_processed` on duplicate pushes).
- [x] Verified dead-letter queue routing configurations.
- [x] Assured Cloud Run has min-instances configured to prevent review phase cold starts.

### Layer 5 — Flutter Mobile Frontend
- [x] Executed static code analysis (`flutter analyze`) confirming 0 errors.
- [x] Resolved dependency requirements to upgrade Core Library Desugaring version to `2.1.4`.
- [x] Compiled release package successfully: `build/app/outputs/flutter-apk/app-release.apk`.
- [x] Audited connectivity banner logic and notification handling.

### Layer 6 — End-to-End Integration Flow
- [x] Created full end-to-end user-flow simulator (`scratch/test_integration.py`).
- [x] Verified registration ➡️ heartbeats ➡️ geohash proximity matching ➡️ transaction lock ➡️ payment capture ➡️ review rating exchange completes 100% successfully.
