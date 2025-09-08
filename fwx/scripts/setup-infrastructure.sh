#!/bin/bash

# fwlink Infrastructure Setup Script for Google Cloud
# Project: fynewo
# Usage: ./setup-infrastructure.sh [environment] [region]

set -e

PROJECT_ID="fynewo"
APP_NAME="fwlink"
ENVIRONMENT=${1:-"prod"}
REGION=${2:-"europe-west4"}
DB_INSTANCE_NAME="${APP_NAME}-db-${ENVIRONMENT}"
REDIS_INSTANCE_NAME="${APP_NAME}-redis-${ENVIRONMENT}"

# Timestamp function for progress tracking
timestamp() {
    date '+[%H:%M:%S]'
}

log_with_time() {
    echo "$(timestamp) $1"
}

# Run prerequisite check first
echo "🔍 Running prerequisite check..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! "${SCRIPT_DIR}/check-prerequisites.sh"; then
    echo ""
    echo "❌ Prerequisites check failed. Please fix the issues above before continuing."
    echo "💡 You can also run the check manually: ./fwx/scripts/check-prerequisites.sh"
    exit 1
fi

echo ""
echo "🚀 Prerequisites verified! Starting infrastructure setup..."
echo "Project: ${PROJECT_ID}"
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${REGION}"
echo "----------------------------------------"

# Enable required APIs
log_with_time "📡 Checking and enabling required Google Cloud APIs..."
REQUIRED_APIS=(
    "run.googleapis.com"
    "sql-component.googleapis.com" 
    "sqladmin.googleapis.com"
    "redis.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
    "secretmanager.googleapis.com"
)

APIS_TO_ENABLE=()
for api in "${REQUIRED_APIS[@]}"; do
    if ! gcloud services list --enabled --filter="name:${api}" --format="value(name)" | grep -q "${api}"; then
        APIS_TO_ENABLE+=("$api")
    fi
done

if [ ${#APIS_TO_ENABLE[@]} -gt 0 ]; then
    log_with_time "   Enabling ${#APIS_TO_ENABLE[@]} APIs..."
    gcloud services enable "${APIS_TO_ENABLE[@]}" --project=${PROJECT_ID}
    log_with_time "✅ APIs enabled successfully"
else
    log_with_time "✅ All required APIs already enabled"
fi

# Create Artifact Registry repository
log_with_time "📦 Checking Artifact Registry repository..."
if gcloud artifacts repositories describe ${APP_NAME} --location=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
    log_with_time "✅ Artifact Registry repository already exists"
else
    log_with_time "   Creating Artifact Registry repository..."
    gcloud artifacts repositories create ${APP_NAME} \
        --repository-format=docker \
        --location=${REGION} \
        --description="fwlink container images" \
        --project=${PROJECT_ID}
    log_with_time "✅ Artifact Registry repository created"
fi

# Create secrets
log_with_time "🔐 Checking and creating secrets..."

# JWT Secret
if gcloud secrets describe fwlink-jwt-secret --project=${PROJECT_ID} >/dev/null 2>&1; then
    log_with_time "✅ JWT secret already exists"
else
    log_with_time "   Creating JWT secret..."
    echo -n "$(openssl rand -base64 32)" | gcloud secrets create fwlink-jwt-secret \
        --data-file=- --project=${PROJECT_ID}
    log_with_time "✅ JWT secret created"
fi

# Database Password Secret
if gcloud secrets describe fwlink-db-password --project=${PROJECT_ID} >/dev/null 2>&1; then
    log_with_time "✅ Database password secret already exists"
else
    echo ""
    echo "Database password is required for the fwlink-user database account."
    read -s -p "Enter database password for fwlink user: " DB_PASSWORD
    echo
    if [ -n "$DB_PASSWORD" ]; then
        echo -n "${DB_PASSWORD}" | gcloud secrets create fwlink-db-password \
            --data-file=- --project=${PROJECT_ID}
        log_with_time "✅ Database password secret created"
    else
        echo "❌ Database password cannot be empty"
        exit 1
    fi
fi

# Create Cloud SQL PostgreSQL instance
log_with_time "🗄️  Checking Cloud SQL PostgreSQL instance..."
if gcloud sql instances describe ${DB_INSTANCE_NAME} --project=${PROJECT_ID} >/dev/null 2>&1; then
    log_with_time "✅ Cloud SQL instance already exists"
else
    log_with_time "   Creating Cloud SQL PostgreSQL instance (this may take 5-10 minutes)..."
    START_TIME=$(date +%s)
    gcloud sql instances create ${DB_INSTANCE_NAME} \
        --database-version=POSTGRES_15 \
        --tier=db-f1-micro \
        --region=${REGION} \
        --storage-auto-increase \
        --storage-type=SSD \
        --storage-size=10GB \
        --backup-start-time=03:00 \
        --maintenance-window-day=SUN \
        --maintenance-window-hour=04 \
        --project=${PROJECT_ID}
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    log_with_time "✅ Cloud SQL instance created in ${DURATION} seconds"
fi

# Create database and user
log_with_time "👤 Checking database and user setup..."

# Wait for instance to be ready
log_with_time "⏳ Ensuring Cloud SQL instance is ready..."
gcloud sql instances describe ${DB_INSTANCE_NAME} --project=${PROJECT_ID} --format="value(state)" > /dev/null 2>&1
WAIT_COUNT=0
while [ "$(gcloud sql instances describe ${DB_INSTANCE_NAME} --project=${PROJECT_ID} --format='value(state)' 2>/dev/null)" != "RUNNABLE" ]; do
    WAIT_COUNT=$((WAIT_COUNT + 1))
    log_with_time "   Instance not ready yet, waiting 10 seconds... (${WAIT_COUNT}0s elapsed)"
    sleep 10
done
log_with_time "✅ Cloud SQL instance is ready"

# Create database with better error handling
if gcloud sql databases list --instance=${DB_INSTANCE_NAME} --project=${PROJECT_ID} --filter="name=${APP_NAME}" --format="value(name)" | grep -q "^${APP_NAME}$"; then
    log_with_time "✅ Database '${APP_NAME}' already exists"
else
    log_with_time "   Creating database '${APP_NAME}'..."
    if gcloud sql databases create ${APP_NAME} --instance=${DB_INSTANCE_NAME} --project=${PROJECT_ID}; then
        log_with_time "✅ Database '${APP_NAME}' created successfully"
    else
        log_with_time "❌ Failed to create database. Please check permissions for ${DB_INSTANCE_NAME}"
        echo "   Required role: Cloud SQL Admin or Cloud SQL Editor"
        exit 1
    fi
fi

# Create user with better error handling
if gcloud sql users list --instance=${DB_INSTANCE_NAME} --project=${PROJECT_ID} --filter="name=fwlink-user" --format="value(name)" | grep -q "^fwlink-user$"; then
    log_with_time "✅ User 'fwlink-user' already exists"
else
    log_with_time "   Creating user 'fwlink-user'..."
    if gcloud sql users create fwlink-user --instance=${DB_INSTANCE_NAME} --password="${DB_PASSWORD:-$(gcloud secrets versions access latest --secret=fwlink-db-password --project=${PROJECT_ID})}" --project=${PROJECT_ID}; then
        log_with_time "✅ User 'fwlink-user' created successfully"
    else
        log_with_time "❌ Failed to create database user. Please check permissions for ${DB_INSTANCE_NAME}"
        echo "   Required role: Cloud SQL Admin or Cloud SQL Editor"
        exit 1
    fi
fi

# Create Redis instance (Memorystore)
log_with_time "⚡ Checking Redis instance..."
if gcloud redis instances describe ${REDIS_INSTANCE_NAME} --region=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
    log_with_time "✅ Redis instance already exists"
else
    log_with_time "   Creating Redis instance (this may take 3-5 minutes)..."
    START_TIME=$(date +%s)
    gcloud redis instances create ${REDIS_INSTANCE_NAME} \
        --size=1 \
        --region=${REGION} \
        --redis-version=redis_7_0 \
        --project=${PROJECT_ID}
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    log_with_time "✅ Redis instance created in ${DURATION} seconds"
fi

# Setup VPC connectivity for Redis access
log_with_time "🌐 Setting up VPC connectivity for Redis access..."

# Enable Serverless VPC Access API
log_with_time "   Enabling Serverless VPC Access API..."
if gcloud services list --enabled --filter="name:vpcaccess.googleapis.com" --project=${PROJECT_ID} | grep -q vpcaccess; then
    log_with_time "✅ Serverless VPC Access API already enabled"
else
    gcloud services enable vpcaccess.googleapis.com --project=${PROJECT_ID}
    log_with_time "✅ Serverless VPC Access API enabled"
fi

# Create dedicated subnet for VPC connector (required /28 netmask)
VPC_SUBNET_NAME="${APP_NAME}-vpc-connector-subnet"
if gcloud compute networks subnets describe ${VPC_SUBNET_NAME} --region=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
    log_with_time "✅ VPC connector subnet already exists"
else
    log_with_time "   Creating VPC connector subnet..."
    gcloud compute networks subnets create ${VPC_SUBNET_NAME} \
        --network=default \
        --range=10.8.0.0/28 \
        --region=${REGION} \
        --project=${PROJECT_ID}
    log_with_time "✅ VPC connector subnet created"
fi

# Create VPC connector for Cloud Run to access Redis
VPC_CONNECTOR_NAME="${APP_NAME}-redis-connector"
if gcloud compute networks vpc-access connectors describe ${VPC_CONNECTOR_NAME} --region=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
    CONNECTOR_STATE=$(gcloud compute networks vpc-access connectors describe ${VPC_CONNECTOR_NAME} --region=${REGION} --project=${PROJECT_ID} --format="value(state)" 2>/dev/null)
    if [ "$CONNECTOR_STATE" = "READY" ]; then
        log_with_time "✅ VPC connector already exists and is ready"
    else
        log_with_time "⚠️  VPC connector exists but is in state: ${CONNECTOR_STATE}"
        log_with_time "   This may take a few minutes to become ready"
    fi
else
    log_with_time "   Creating VPC connector (this may take 2-3 minutes)..."
    START_TIME=$(date +%s)
    gcloud compute networks vpc-access connectors create ${VPC_CONNECTOR_NAME} \
        --region=${REGION} \
        --subnet=${VPC_SUBNET_NAME} \
        --subnet-project=${PROJECT_ID} \
        --min-instances=2 \
        --max-instances=3 \
        --project=${PROJECT_ID}
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    log_with_time "✅ VPC connector created in ${DURATION} seconds"
fi

# Setup Mailgun for email service
log_with_time "📧 Checking Mailgun email service setup..."

# Check if Mailgun secrets already exist
MAILGUN_KEY_EXISTS=$(gcloud secrets describe fwlink-mailgun-api-key --project=${PROJECT_ID} >/dev/null 2>&1 && echo "true" || echo "false")
MAILGUN_HOST_EXISTS=$(gcloud secrets describe fwlink-mailgun-host --project=${PROJECT_ID} >/dev/null 2>&1 && echo "true" || echo "false")

if [ "$MAILGUN_KEY_EXISTS" = "true" ] && [ "$MAILGUN_HOST_EXISTS" = "true" ]; then
    log_with_time "✅ Mailgun configuration already exists"
else
    log_with_time "   Setting up Mailgun email service..."
    echo ""
    echo "📧 Mailgun Setup Required"
    echo "========================"
    echo "Please follow these steps to set up Mailgun:"
    echo ""
    echo "1. Log into your existing Mailgun account at: https://app.mailgun.com/"
    echo "2. Go to 'Sending' > 'Domains' and add domain: fwl.ink"
    echo "3. Configure DNS records for fwl.ink as shown in Mailgun dashboard"
    echo "4. Go to 'Domain Settings' > 'SMTP credentials' and add a new user:"
    echo "   - Login: postmaster@fwl.ink"
    echo "   - Generate a password (save both username and password)"
    echo "5. Note your Mailgun region (US or EU) for SMTP host"
    echo ""
    read -p "Press Enter after you've completed Mailgun domain setup and created SMTP credentials..."
    echo ""

    # Get Mailgun SMTP password
    echo "Enter your Mailgun SMTP password (from step 4 above):"
    echo "Note: Input will be hidden for security"
    read -s MAILGUN_SMTP_PASSWORD
    echo ""
    
    # Validate SMTP password format (basic check)
    if [ -z "$MAILGUN_SMTP_PASSWORD" ]; then
        echo "❌ SMTP password cannot be empty"
        exit 1
    fi
    
    if [ ${#MAILGUN_SMTP_PASSWORD} -lt 8 ]; then
        echo "⚠️  Warning: SMTP password seems too short (less than 8 characters)"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_with_time "❌ Setup cancelled by user"
            exit 1
        fi
    fi
    
    echo "SMTP password received (${#MAILGUN_SMTP_PASSWORD} characters)"

    # Get Mailgun region
    echo ""
    echo "Select your Mailgun region:"
    echo "1) US (smtp.mailgun.org)"
    echo "2) EU (smtp.eu.mailgun.org)"
    while true; do
        read -p "Enter choice (1 or 2): " MAILGUN_REGION_CHOICE
        case $MAILGUN_REGION_CHOICE in
            1)
                MAILGUN_HOST="smtp.mailgun.org"
                echo "Selected: US region (${MAILGUN_HOST})"
                break
                ;;
            2)
                MAILGUN_HOST="smtp.eu.mailgun.org"
                echo "Selected: EU region (${MAILGUN_HOST})"
                break
                ;;
            *)
                echo "Please enter 1 or 2"
                ;;
        esac
    done

    # Store Mailgun secrets
    log_with_time "   Storing Mailgun configuration in Secret Manager..."
    
    if [ "$MAILGUN_KEY_EXISTS" = "false" ]; then
        echo -n "${MAILGUN_SMTP_PASSWORD}" | gcloud secrets create fwlink-mailgun-api-key \
            --data-file=- --project=${PROJECT_ID}
        log_with_time "✅ Mailgun SMTP password stored"
    fi
    
    if [ "$MAILGUN_HOST_EXISTS" = "false" ]; then
        echo -n "${MAILGUN_HOST}" | gcloud secrets create fwlink-mailgun-host \
            --data-file=- --project=${PROJECT_ID}
        log_with_time "✅ Mailgun host (${MAILGUN_HOST}) stored"
    fi
fi

log_with_time "✅ Infrastructure setup complete!"
echo ""
echo "📋 Resource Summary:"
echo "- Cloud SQL Instance: ${DB_INSTANCE_NAME}"
echo "- Database: ${APP_NAME}"
echo "- Database User: fwlink-user"
echo "- Redis Instance: ${REDIS_INSTANCE_NAME}"
echo "- VPC Connector: ${VPC_CONNECTOR_NAME} (for Redis access)"
echo "- VPC Subnet: ${VPC_SUBNET_NAME} (10.8.0.0/28)"
echo "- Mailgun Email Service: fwl.ink domain"
echo "- Artifact Registry: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${APP_NAME}"
echo ""
echo "🔍 Get connection details:"
echo "gcloud sql instances describe ${DB_INSTANCE_NAME} --project=${PROJECT_ID}"
echo "gcloud redis instances describe ${REDIS_INSTANCE_NAME} --region=${REGION} --project=${PROJECT_ID}"
echo "gcloud compute networks vpc-access connectors describe ${VPC_CONNECTOR_NAME} --region=${REGION} --project=${PROJECT_ID}"
echo ""
log_with_time "🚀 Ready for deployment! Run: ./fwx/scripts/deploy.sh"