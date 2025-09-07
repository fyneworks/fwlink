#!/bin/bash

# fwlink Deployment Script
# Builds and deploys fwlink to Google Cloud Run

set -e

PROJECT_ID="fynewo"
APP_NAME="fwlink"
ENVIRONMENT=${1:-"prod"}
REGION=${2:-"europe-west4"}
SERVICE_NAME="${APP_NAME}-${ENVIRONMENT}"

# Quick readiness check
echo "🔍 Checking deployment readiness..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Basic checks only for deploy (infrastructure should already exist)
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud CLI not found. Install first: curl https://sdk.cloud.google.com | bash"
    exit 1
fi

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null 2>&1; then
    echo "❌ Not authenticated. Run: gcloud auth login"
    exit 1
fi

CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
    echo "❌ Wrong project: ${CURRENT_PROJECT:-none}, expected: ${PROJECT_ID}"
    echo "   Fix: gcloud config set project ${PROJECT_ID}"
    exit 1
fi

echo "✅ Basic requirements verified"
echo ""
echo "🚀 Deploying fwlink to Google Cloud Run..."
echo "Project: ${PROJECT_ID}"
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${REGION}"
echo "Service: ${SERVICE_NAME}"
echo "----------------------------------------"

# Get Redis IP
echo "🔍 Getting Redis IP address..."
REDIS_IP=$(./fwx/scripts/get-redis-ip.sh ${ENVIRONMENT} ${REGION} | grep "Redis IP:" | cut -d' ' -f3)

if [ -z "$REDIS_IP" ]; then
    echo "❌ Could not get Redis IP. Please ensure Redis instance is created."
    exit 1
fi

echo "✅ Redis IP: ${REDIS_IP}"

# Generate image tag from timestamp and git info if available
if git rev-parse --short HEAD >/dev/null 2>&1; then
    IMAGE_TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)"
else
    IMAGE_TAG="$(date +%Y%m%d%H%M%S)"
fi

# Submit build to Cloud Build
echo "🔨 Starting Cloud Build with image tag: ${IMAGE_TAG}..."
gcloud builds submit \
    --config=fwx/gcp/cloudbuild.yaml \
    --substitutions=_ENVIRONMENT=${ENVIRONMENT},_REGION=${REGION},_IMAGE_TAG=${IMAGE_TAG} \
    --project=${PROJECT_ID}

# Update Cloud Run service with Redis IP
echo "⚡ Updating Redis configuration..."
gcloud run services update ${SERVICE_NAME} \
    --update-env-vars REDIS_HOST=${REDIS_IP} \
    --region=${REGION} \
    --project=${PROJECT_ID}

# Get service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    --format="value(status.url)")

echo "✅ Deployment complete!"
echo ""
echo "🌐 Service URL: ${SERVICE_URL}"
echo "📊 Monitor logs: gcloud logs tail --project=${PROJECT_ID} --filter='resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE_NAME}'"
echo "🔧 Update service: gcloud run services update ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID}"