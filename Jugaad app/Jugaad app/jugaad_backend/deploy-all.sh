#!/bin/bash
# ====================================================================
# JUGAAD — FULL DEPLOYMENT SCRIPT
# Deploys Firestore indexes + rules + all 9 Cloud Run services
# Usage: ./deploy-all.sh
# ====================================================================
set -euo pipefail

PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-jugaad-prod-app-2026}
REGION=${GCP_REGION:-asia-south1}
SERVICES=(
  auth_service
  worker_service
  user_service
  admin_service
  booking_service
  payment_service
  review_service
  matching_service
  notification_service
)

echo "=========================================="
echo "JUGAAD DEPLOYMENT — Project: $PROJECT_ID"
echo "Region: $REGION"
echo "=========================================="

# ─── STEP 1: Deploy Firestore indexes (MUST be first) ──────────
echo ""
echo "[1/3] Deploying Firestore indexes..."
echo "  ⚠️  CRITICAL: Matching service will FAIL without these indexes"
firebase deploy --only firestore:indexes --project "$PROJECT_ID"
echo "  ✅ Indexes deployed"

# ─── STEP 2: Deploy Firestore security rules ───────────────────
echo ""
echo "[2/3] Deploying Firestore security rules..."
firebase deploy --only firestore:rules --project "$PROJECT_ID"
echo "  ✅ Rules deployed"

# ─── STEP 3: Deploy all Cloud Run services ─────────────────────
echo ""
echo "[3/3] Deploying Cloud Run services..."
for SERVICE in "${SERVICES[@]}"; do
  echo ""
  SERVICE_HYPHEN=$(echo "$SERVICE" | tr '_' '-')
  echo "  → Deploying $SERVICE as $SERVICE_HYPHEN..."
  gcloud run deploy "jugaad-$SERVICE_HYPHEN" \
    --source . \
    --region "$REGION" \
    --platform managed \
    --ingress internal-and-cloud-load-balancing \
    --no-allow-unauthenticated \
    --set-env-vars "SERVICE_NAME=$SERVICE" \
    --project "$PROJECT_ID" \
    --quiet
  echo "  ✅ $SERVICE deployed"
done

echo ""
echo "=========================================="
echo "ALL SERVICES DEPLOYED"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Verify health: curl <SERVICE_URL>/health"
echo "  2. Set up Pub/Sub push subscriptions"
echo "  3. Configure API Gateway routes"
echo "  4. Set QStash callback URLs in env vars"
echo "  5. Run end-to-end test: create_job → match → assign → complete"
