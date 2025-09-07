#!/bin/bash

# Helper script to update Mailgun secrets manually
# Usage: ./update-mailgun-secret.sh

set -e

PROJECT_ID="fynewo"

echo "🔧 Mailgun Secret Update Helper"
echo "==============================="
echo ""

# Check current secrets
echo "Current Mailgun secrets:"
if gcloud secrets describe fwlink-mailgun-api-key --project=${PROJECT_ID} >/dev/null 2>&1; then
    echo "✅ fwlink-mailgun-api-key exists"
else
    echo "❌ fwlink-mailgun-api-key missing"
fi

if gcloud secrets describe fwlink-mailgun-host --project=${PROJECT_ID} >/dev/null 2>&1; then
    echo "✅ fwlink-mailgun-host exists"
    CURRENT_HOST=$(gcloud secrets versions access latest --secret=fwlink-mailgun-host --project=${PROJECT_ID})
    echo "   Current host: ${CURRENT_HOST}"
else
    echo "❌ fwlink-mailgun-host missing"
fi

echo ""

# Update API key
read -p "Update Mailgun API key? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Enter your Mailgun Private API key (starts with 'key-'):"
    echo "Note: Input will be hidden for security"
    read -s MAILGUN_API_KEY
    echo ""
    
    if [ -n "$MAILGUN_API_KEY" ]; then
        echo "API key received (${#MAILGUN_API_KEY} characters)"
        
        # Validate format
        if [[ "$MAILGUN_API_KEY" =~ ^key-[a-f0-9]{32}$ ]]; then
            echo "✅ API key format looks correct"
        else
            echo "⚠️  Warning: API key format doesn't match expected pattern"
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Aborted."
                exit 1
            fi
        fi
        
        # Update secret
        echo -n "${MAILGUN_API_KEY}" | gcloud secrets versions add fwlink-mailgun-api-key --data-file=- --project=${PROJECT_ID}
        echo "✅ Mailgun API key updated"
    else
        echo "❌ API key cannot be empty"
    fi
fi

echo ""

# Update region/host
read -p "Update Mailgun region/host? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Select your Mailgun region:"
    echo "1) US (smtp.mailgun.org)"
    echo "2) EU (smtp.eu.mailgun.org)"
    
    while true; do
        read -p "Enter choice (1 or 2): " REGION_CHOICE
        case $REGION_CHOICE in
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
    
    # Update host secret
    echo -n "${MAILGUN_HOST}" | gcloud secrets versions add fwlink-mailgun-host --data-file=- --project=${PROJECT_ID}
    echo "✅ Mailgun host updated to ${MAILGUN_HOST}"
fi

echo ""
echo "🚀 Done! If you made changes, redeploy to pick them up:"
echo "   ./fwx/scripts/deploy.sh"