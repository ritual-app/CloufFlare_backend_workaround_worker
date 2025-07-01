#!/bin/bash

# Simple Worker Health Dashboard
# Uses the working /worker-health endpoint

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
WORKER_URL="https://ritualx-dev.ritual-app.co"
REFRESH_INTERVAL=5

show_dashboard() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🚀 WORKER HEALTH DASHBOARD - $timestamp${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    # Get health data
    local health_response=$(curl -s "$WORKER_URL/worker-health" 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$health_response" | jq . >/dev/null 2>&1; then
        # Parse health data
        local status=$(echo "$health_response" | jq -r '.status // "unknown"')
        local env=$(echo "$health_response" | jq -r '.environment // "unknown"')
        local routing_enabled=$(echo "$health_response" | jq -r '.routing_enabled // false')
        local canary_percent=$(echo "$health_response" | jq -r '.canary_percent // 0')
        local backend_healthy=$(echo "$health_response" | jq -r '.backend_healthy // false')
        local backend_time=$(echo "$health_response" | jq -r '.backend_response_time_ms // 0')
        local worker_time=$(echo "$health_response" | jq -r '.worker_response_time_ms // 0')
        
        # Status color
        if [ "$status" = "healthy" ]; then
            status_color="${GREEN}"
        else
            status_color="${RED}"
        fi
        
        # Routing status color
        if [ "$routing_enabled" = "true" ]; then
            routing_color="${GREEN}"
        else
            routing_color="${YELLOW}"
        fi
        
        # Backend status color
        if [ "$backend_healthy" = "true" ]; then
            backend_color="${GREEN}"
        else
            backend_color="${RED}"
        fi
        
        echo -e "${PURPLE}📊 SYSTEM STATUS${NC}"
        echo -e "Status: ${status_color}$status${NC}"
        echo -e "Environment: ${BLUE}$env${NC}"
        echo -e "Worker Response Time: ${BLUE}${worker_time}ms${NC}"
        echo ""
        
        echo -e "${PURPLE}🔀 ROUTING STATUS${NC}"
        echo -e "Routing Enabled: ${routing_color}$routing_enabled${NC}"
        echo -e "Canary Percentage: ${YELLOW}$canary_percent%${NC}"
        echo ""
        
        echo -e "${PURPLE}🔧 BACKEND STATUS${NC}"
        echo -e "Backend Healthy: ${backend_color}$backend_healthy${NC}"
        echo -e "Backend Response Time: ${BLUE}${backend_time}ms${NC}"
        echo ""
        
        # Traffic simulation with visual bar
        echo -e "${PURPLE}🚦 TRAFFIC ROUTING VISIBILITY${NC}"
        if [ "$routing_enabled" = "true" ] && [ "$canary_percent" -gt 0 ]; then
            local routed_requests=$((canary_percent))
            local passthrough_requests=$((100 - canary_percent))
            
            echo -e "Canary Rollout: ${YELLOW}$canary_percent%${NC} → Django Backend"
            echo -e "Pass-through: ${BLUE}$passthrough_requests%${NC} → RitualX Frontend"
            
            # Visual bar representation
            local bar_length=50
            local routed_bar_length=$((routed_requests * bar_length / 100))
            local passthrough_bar_length=$((bar_length - routed_bar_length))
            
            printf "Visual: ["
            printf "${GREEN}%*s${NC}" $routed_bar_length | tr ' ' '█'
            printf "${BLUE}%*s${NC}" $passthrough_bar_length | tr ' ' '█'
            printf "]\n"
            echo -e "        ${GREEN}Django${NC}$(printf "%*s" $((routed_bar_length-6)) "")${BLUE}RitualX${NC}"
        else
            echo -e "Status: ${BLUE}All requests pass-through (no routing active)${NC}"
            printf "Visual: [${BLUE}%50s${NC}]\n" | tr ' ' '█'
            echo -e "        ${BLUE}All traffic → RitualX Frontend${NC}"
        fi
        
    else
        echo -e "${RED}❌ Failed to fetch worker health${NC}"
        echo -e "URL: $WORKER_URL/worker-health"
        if [ ! -z "$health_response" ]; then
            echo -e "Response: $health_response"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔄 Auto-refresh in ${REFRESH_INTERVAL}s | Press Ctrl+C to exit${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Test a few backend requests
test_requests() {
    echo -e "\n${PURPLE}🧪 TESTING BACKEND REQUESTS${NC}"
    
    for i in {1..3}; do
        local start_time=$(date +%s%N)
        local response=$(curl -s -w "%{http_code}" "$WORKER_URL/backend/health_check" 2>/dev/null)
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))
        
        local http_code="${response: -3}"
        
        if [ "$http_code" = "200" ]; then
            echo -e "Test $i: ${GREEN}✓ $http_code${NC} (${duration}ms)"
        else
            echo -e "Test $i: ${RED}✗ $http_code${NC} (${duration}ms)"
        fi
        sleep 0.5
    done
}

# Main loop
echo -e "${GREEN}🚀 Starting Worker Health Dashboard...${NC}"
echo -e "${BLUE}Monitor URL: $WORKER_URL${NC}"

while true; do
    show_dashboard
    
    # Run tests every few cycles
    if [ $(($(date +%s) % 30)) -eq 0 ]; then
        test_requests
    fi
    
    sleep $REFRESH_INTERVAL
done