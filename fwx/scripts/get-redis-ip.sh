#!/bin/bash

# Get Redis IP address for fwlink deployment
PROJECT_ID="fynewo"
ENVIRONMENT=${1:-"prod"}
REGION=${2:-"europe-west4"}
REDIS_INSTANCE_NAME="fwlink-redis-${ENVIRONMENT}"

echo "🔍 Getting Redis IP address..."
REDIS_IP=$(gcloud redis instances describe ${REDIS_INSTANCE_NAME} \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    --format="value(host)")

if [ -n "$REDIS_IP" ]; then
    echo "Redis IP: $REDIS_IP"
    echo "Use this IP in your REDIS_HOST environment variable"
else
    echo "❌ Could not retrieve Redis IP. Make sure the instance exists."
    exit 1
fi