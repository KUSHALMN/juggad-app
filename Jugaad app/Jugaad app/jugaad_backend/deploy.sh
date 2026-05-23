#!/bin/bash
SERVICE=$1
REGION=${GCP_REGION:-asia-south1}

if [ -z "$SERVICE" ]; then
  echo "Usage: ./deploy.sh <service_name>"
  exit 1
fi

# ALL services: internal ingress only. QStash reaches them through
# the API Gateway /internal/* path mapping — NOT direct public URLs.
echo "Deploying $SERVICE (region: $REGION, ingress: internal-and-cloud-load-balancing)"
gcloud run deploy jugaad-$SERVICE \
  --source . \
  --build-arg SERVICE_NAME=$SERVICE \
  --region $REGION \
  --platform managed \
  --ingress internal-and-cloud-load-balancing \
  --no-allow-unauthenticated \
  --set-env-vars SERVICE_NAME=$SERVICE \
  --traffic 1
echo "Deployed. Canary at 1%. Monitor logs before increasing traffic."
