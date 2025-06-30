#!/bin/bash

# Create Cloudflare Analytics Dashboard via CLI
# Requirements: CF_API_TOKEN, CF_ACCOUNT_ID in .env file

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Configuration - Load from environment
ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-your_account_id_here}"
DATASET_NAME="${CF_DATASET_NAME:-routing_metrics_dev}"
REFRESH_INTERVAL="${DASHBOARD_REFRESH_INTERVAL:-30}"

# Environment profile (dev/prod)
ENV_PROFILE="${ENV_PROFILE:-dev}"
if [ "$ENV_PROFILE" = "prod" ]; then
    DATASET_NAME="${CF_DATASET_NAME:-routing_backend_prod}"
else
    DATASET_NAME="${CF_DATASET_NAME:-routing_backend_dev}"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

clear
echo -e "${GREEN}🚀 Cloudflare Worker Analytics Dashboard${NC}"
echo -e "${BLUE}Environment: $ENV_PROFILE | Dataset: $DATASET_NAME${NC}"
echo -e "${BLUE}Account: ${ACCOUNT_ID:0:8}...${NC}"
echo -e "${YELLOW}Press Ctrl+C to exit${NC}\n"

# Check if required variables are set
if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${RED}❌ CF_API_TOKEN not found in .env file${NC}"
    echo "1. Copy .env.example to .env"
    echo "2. Get your token from: https://dash.cloudflare.com/profile/api-tokens"
    echo "3. Add CF_API_TOKEN=your_token_here to .env"
    exit 1
fi

if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
    echo -e "${RED}❌ CLOUDFLARE_ACCOUNT_ID not found in .env file${NC}"
    echo "Add CLOUDFLARE_ACCOUNT_ID=your_account_id_here to .env"
    exit 1
fi

# Function to run Analytics QL query
run_query() {
    local query="$1"
    local description="$2"
    local format="$3"
    
    echo -e "${PURPLE}📊 $description${NC}"
    
    local response=$(curl -s -X POST \
        "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/analytics_engine/sql" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: text/plain" \
        -d "$query")
    
    # Check for API errors
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        echo -e "${RED}❌ Invalid JSON Response:${NC}"
        echo "$response" | head -1
        return 1
    fi
    
    local success=$(echo "$response" | jq -r '.success // false')
    if [ "$success" != "true" ]; then
        echo -e "${RED}❌ API Error:${NC}"
        echo "$response" | jq -r '.errors[0].message // "Unknown error"' 2>/dev/null || echo "$response"
        return 1
    fi
    
    # Format and display results
    if [ "$format" == "table" ]; then
        echo "$response" | jq -r '.result.data[] | @csv' | column -t -s','
    elif [ "$format" == "json" ]; then
        echo "$response" | jq -r '.result.data'
    else
        echo "$response" | jq -r '.result.data[] | @csv'
    fi
    echo ""
}

# Function to display dashboard
show_dashboard() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}📈 LIVE DASHBOARD - $timestamp${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    # 1. Total event count
    run_query "SELECT COUNT() FROM $DATASET_NAME" "🔥 Total Events in Dataset" "table"
    
    # 2. Recent data sample
    run_query "SELECT * FROM $DATASET_NAME LIMIT 3" "📋 Recent Data Sample" "table"
    
    echo -e "${YELLOW}💡 Analytics Engine Note: Data is stored in blob1-20 and double1-20 columns${NC}"
    echo -e "${YELLOW}💡 Use the health dashboard (npm run dashboard) for real-time monitoring${NC}"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔄 Auto-refresh in ${REFRESH_INTERVAL}s | Press Ctrl+C to exit${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

# Main dashboard loop
while true; do
    show_dashboard
    sleep $REFRESH_INTERVAL
    clear
done