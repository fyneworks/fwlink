#!/bin/bash

# fwlink Prerequisites Checker
# Verifies all requirements are met before infrastructure setup

set -e

PROJECT_ID="fynewo"
REGION="europe-west4"
REQUIRED_APIS=(
    "run.googleapis.com"
    "sql-component.googleapis.com" 
    "sqladmin.googleapis.com"
    "redis.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
    "secretmanager.googleapis.com"
    "compute.googleapis.com"
)

echo "🔍 fwlink Prerequisites Checker"
echo "================================"
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track overall status
OVERALL_STATUS="pass"
WARNINGS=0
ERRORS=0

print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "pass")
            echo -e "✅ ${GREEN}PASS${NC} - $message"
            ;;
        "warn")
            echo -e "⚠️  ${YELLOW}WARN${NC} - $message"
            ((WARNINGS++))
            ;;
        "fail")
            echo -e "❌ ${RED}FAIL${NC} - $message"
            ((ERRORS++))
            OVERALL_STATUS="fail"
            ;;
        "info")
            echo -e "ℹ️  ${BLUE}INFO${NC} - $message"
            ;;
    esac
}

# Check 1: Google Cloud CLI installed
echo "1️⃣  Checking Google Cloud CLI..."
if command -v gcloud &> /dev/null; then
    GCLOUD_VERSION=$(gcloud --version | head -n1 | cut -d' ' -f4)
    print_status "pass" "Google Cloud CLI installed (${GCLOUD_VERSION})"
else
    print_status "fail" "Google Cloud CLI not found"
    echo "   Install: curl https://sdk.cloud.google.com | bash"
    echo ""
fi

# Check 2: Authentication
echo ""
echo "2️⃣  Checking authentication..."
if gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null 2>&1; then
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
    print_status "pass" "Authenticated as: ${ACTIVE_ACCOUNT}"
    
    # Check application default credentials
    if gcloud auth application-default print-access-token > /dev/null 2>&1; then
        print_status "pass" "Application default credentials configured"
    else
        print_status "warn" "Application default credentials not set"
        echo "   Run: gcloud auth application-default login"
    fi
else
    print_status "fail" "Not authenticated with Google Cloud"
    echo "   Run: gcloud auth login"
    echo ""
fi

# Check 3: Project configuration
echo ""
echo "3️⃣  Checking project configuration..."
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [ "$CURRENT_PROJECT" = "$PROJECT_ID" ]; then
    print_status "pass" "Project set to: ${PROJECT_ID}"
else
    if [ -z "$CURRENT_PROJECT" ]; then
        print_status "fail" "No project configured"
    else
        print_status "warn" "Project set to: ${CURRENT_PROJECT}, expected: ${PROJECT_ID}"
    fi
    echo "   Run: gcloud config set project ${PROJECT_ID}"
fi

# Check 4: Project exists and accessible
echo ""
echo "4️⃣  Checking project access..."
if gcloud projects describe $PROJECT_ID > /dev/null 2>&1; then
    print_status "pass" "Project ${PROJECT_ID} accessible"
    
    # Check if billing is enabled
    BILLING_ACCOUNT=$(gcloud beta billing projects describe $PROJECT_ID --format="value(billingAccountName)" 2>/dev/null || echo "")
    if [ -n "$BILLING_ACCOUNT" ]; then
        print_status "pass" "Billing enabled on project"
    else
        print_status "fail" "Billing not enabled on project ${PROJECT_ID}"
        echo "   Enable billing: https://console.cloud.google.com/billing/linkedaccount?project=${PROJECT_ID}"
    fi
else
    print_status "fail" "Cannot access project ${PROJECT_ID}"
    echo "   Check project exists and you have permissions"
fi

# Check 5: Required APIs
echo ""
echo "5️⃣  Checking required APIs..."
DISABLED_APIS=()
ENABLED_APIS=()

for api in "${REQUIRED_APIS[@]}"; do
    if gcloud services list --enabled --filter="name:${api}" --format="value(name)" | grep -q "${api}"; then
        ENABLED_APIS+=("$api")
        print_status "pass" "${api} enabled"
    else
        DISABLED_APIS+=("$api")
        print_status "warn" "${api} disabled"
    fi
done

if [ ${#DISABLED_APIS[@]} -gt 0 ]; then
    echo ""
    print_status "info" "Will enable ${#DISABLED_APIS[@]} APIs during setup:"
    for api in "${DISABLED_APIS[@]}"; do
        echo "   - $api"
    done
fi

# Check 6: Region availability
echo ""
echo "6️⃣  Checking region availability..."

# Check basic region availability
if gcloud compute regions list --filter="name:${REGION}" --format="value(name)" 2>/dev/null | grep -q "${REGION}"; then
    print_status "pass" "Region ${REGION} available for Compute"
else
    print_status "fail" "Region ${REGION} not available for Compute"
    echo "   Available regions: gcloud compute regions list"
fi

# Check Cloud SQL availability (may fail if SQL API not enabled yet)
if gcloud sql tiers list --filter="region:${REGION}" --format="value(tier)" 2>/dev/null | head -n1 > /dev/null; then
    print_status "pass" "Cloud SQL available in ${REGION}"
elif gcloud sql tiers list 2>/dev/null | grep -q "${REGION}"; then
    print_status "pass" "Cloud SQL available in ${REGION}"
else
    print_status "info" "Cloud SQL availability will be verified when SQL API is enabled"
fi

# Check Redis availability (may fail if Redis API not enabled yet)
REDIS_CHECK_OUTPUT=$(gcloud redis regions list --format="value(name)" 2>&1)
if echo "$REDIS_CHECK_OUTPUT" | grep -q "API.*not enabled"; then
    print_status "info" "Redis availability will be verified when Redis API is enabled"
elif echo "$REDIS_CHECK_OUTPUT" | grep -q "${REGION}"; then
    print_status "pass" "Redis available in ${REGION}"
else
    # Check region family (Redis often uses europe-west4 not europe-west4-a)
    REDIS_REGION_FAMILY="${REGION%%-*}"
    if echo "$REDIS_CHECK_OUTPUT" | grep -q "${REDIS_REGION_FAMILY}"; then
        print_status "pass" "Redis available in ${REDIS_REGION_FAMILY} region family"
    else
        print_status "info" "Redis availability will be verified during setup"
    fi
fi

# Check Cloud Run availability (may fail if Cloud Run API not enabled yet)
RUN_CHECK_OUTPUT=$(gcloud run regions list --format="value(name)" 2>&1)
if echo "$RUN_CHECK_OUTPUT" | grep -q "API.*not enabled"; then
    print_status "info" "Cloud Run availability will be verified when Cloud Run API is enabled"
elif echo "$RUN_CHECK_OUTPUT" | grep -q "${REGION}"; then
    print_status "pass" "Cloud Run available in ${REGION}"
else
    print_status "info" "Cloud Run availability will be verified during setup"
fi

# Check 7: Required tools
echo ""
echo "7️⃣  Checking additional tools..."
if command -v curl &> /dev/null; then
    print_status "pass" "curl available"
else
    print_status "warn" "curl not found (needed for downloads)"
fi

if command -v docker &> /dev/null; then
    print_status "pass" "Docker available"
else
    print_status "warn" "Docker not found (useful for local testing)"
fi

# Check 8: Basic project access (simplified quota check)
echo ""
echo "8️⃣  Checking project resource access..."

# Simple check - can we access project info at all?
if gcloud compute project-info describe --format="value(name)" 2>/dev/null > /dev/null; then
    print_status "pass" "Project resource information accessible"
elif gcloud projects describe $PROJECT_ID --format="value(name)" 2>/dev/null > /dev/null; then
    print_status "info" "Project accessible (detailed quotas will be checked when Compute API is enabled)"
else
    print_status "warn" "Cannot access project resource information"
    echo "   This may indicate insufficient permissions or API access issues"
fi

# Check 9: Existing resources (to avoid conflicts)
echo ""
echo "9️⃣  Checking for existing resources..."
EXISTING_RESOURCES=()

# Check Cloud SQL
if gcloud sql instances list --filter="name:fwlink-db-prod" --format="value(name)" 2>/dev/null | grep -q "fwlink-db-prod"; then
    EXISTING_RESOURCES+=("Cloud SQL: fwlink-db-prod")
fi

# Check Redis  
if gcloud redis instances list --region=$REGION --filter="name:fwlink-redis-prod" --format="value(name)" 2>/dev/null | grep -q "fwlink-redis-prod"; then
    EXISTING_RESOURCES+=("Redis: fwlink-redis-prod")
fi

# Check Cloud Run
if gcloud run services list --region=$REGION --filter="metadata.name:fwlink-prod" --format="value(metadata.name)" 2>/dev/null | grep -q "fwlink-prod"; then
    EXISTING_RESOURCES+=("Cloud Run: fwlink-prod")
fi

# Check Artifact Registry
if gcloud artifacts repositories list --location=$REGION --filter="name:fwlink" --format="value(name)" 2>/dev/null | grep -q "fwlink"; then
    EXISTING_RESOURCES+=("Artifact Registry: fwlink")
fi

if [ ${#EXISTING_RESOURCES[@]} -gt 0 ]; then
    print_status "info" "Found existing resources (setup will skip these):"
    for resource in "${EXISTING_RESOURCES[@]}"; do
        echo "   - $resource"
    done
    echo "   This is normal for subsequent deployments or updates"
else
    print_status "pass" "No existing resources found"
fi

# Summary
echo ""
echo "📋 SUMMARY"
echo "=========="
echo "Checks completed: 9"
echo "Warnings: ${WARNINGS}"
echo "Errors: ${ERRORS}"

if [ "$OVERALL_STATUS" = "pass" ] && [ $ERRORS -eq 0 ]; then
    echo ""
    print_status "pass" "All prerequisites met! Ready to proceed with setup."
    echo ""
    echo "Next steps:"
    echo "1. Run: ./fwx/scripts/setup-infrastructure.sh"
    echo "2. Run: ./fwx/scripts/deploy.sh"
    
    # Auto-enable APIs if requested
    if [ ${#DISABLED_APIS[@]} -gt 0 ]; then
        echo ""
        read -p "Enable ${#DISABLED_APIS[@]} required APIs now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "🔧 Enabling APIs..."
            gcloud services enable "${DISABLED_APIS[@]}" --project=$PROJECT_ID
            echo "✅ APIs enabled successfully!"
        else
            echo ""
            print_status "info" "APIs will be enabled during infrastructure setup"
        fi
    fi
    
    exit 0
else
    echo ""
    print_status "fail" "Prerequisites not met. Please fix the issues above."
    
    if [ $ERRORS -gt 0 ]; then
        echo ""
        echo "🛠️  REQUIRED FIXES:"
        echo "- Fix all FAIL items above before proceeding"
    fi
    
    if [ $WARNINGS -gt 0 ]; then
        echo ""
        echo "⚠️  OPTIONAL FIXES:"
        echo "- WARN items are recommended but not required"
    fi
    
    exit 1
fi