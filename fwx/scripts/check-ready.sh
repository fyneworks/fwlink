#!/bin/bash

# Quick prerequisite check for fwlink deployment
# This is a lightweight version that can be run anytime

echo "🔍 Quick Readiness Check for fwlink"
echo "===================================="

# Check if we can run the full prerequisite check
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "${SCRIPT_DIR}/check-prerequisites.sh" ]; then
    # Run the full check
    exec "${SCRIPT_DIR}/check-prerequisites.sh"
else
    echo "❌ Prerequisite checker not found at: ${SCRIPT_DIR}/check-prerequisites.sh"
    echo ""
    echo "Basic checks:"
    
    # Basic gcloud check
    if command -v gcloud &> /dev/null; then
        echo "✅ Google Cloud CLI installed"
        
        # Check if authenticated
        if gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null 2>&1; then
            echo "✅ Authenticated with Google Cloud"
            
            # Check project
            CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
            if [ "$CURRENT_PROJECT" = "fynewo" ]; then
                echo "✅ Project set to: fynewo"
                echo ""
                echo "🚀 Basic requirements met. Run full check with:"
                echo "   ./fwx/scripts/check-prerequisites.sh"
            else
                echo "❌ Project not set to 'fynewo' (current: ${CURRENT_PROJECT:-none})"
                echo "   Fix: gcloud config set project fynewo"
            fi
        else
            echo "❌ Not authenticated with Google Cloud"
            echo "   Fix: gcloud auth login"
        fi
    else
        echo "❌ Google Cloud CLI not installed"
        echo "   Install: curl https://sdk.cloud.google.com | bash"
    fi
    
    exit 1
fi