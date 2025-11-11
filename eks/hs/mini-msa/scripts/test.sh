#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Mini MSA Integration Test ===${NC}\n"

# Check if services are running
echo -e "${YELLOW}Checking if services are running...${NC}"
if ! curl -s http://localhost:3001/health > /dev/null 2>&1; then
    echo -e "${RED}❌ Queue service is not running on port 3001${NC}"
    echo -e "${YELLOW}Please start services with: make up${NC}"
    exit 1
fi

if ! curl -s http://localhost:3002/health > /dev/null 2>&1; then
    echo -e "${RED}❌ Core service is not running on port 3002${NC}"
    echo -e "${YELLOW}Please start services with: make up${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Both services are running${NC}\n"

# Wait for services to be fully ready
echo -e "${YELLOW}Waiting for services to be fully ready...${NC}"
sleep 2

# Test Queue Service Health
echo -e "\n${GREEN}1. Queue Service Health Check${NC}"
curl -s http://localhost:3001/health | jq '.'

# Test Core Service Health
echo -e "\n${GREEN}2. Core Service Health Check${NC}"
curl -s http://localhost:3002/health | jq '.'

# Test Core Service checking Queue Service
echo -e "\n${GREEN}3. Core Service -> Queue Service Health Check${NC}"
curl -s http://localhost:3002/api/check-queue | jq '.'

# Create a job via Core Service
echo -e "\n${GREEN}4. Create Job via Core Service${NC}"
curl -s -X POST http://localhost:3002/api/jobs \
  -H "Content-Type: application/json" \
  -d '{"type":"data-processing","data":"sample data 1","priority":"high"}' | jq '.'

# Create another job
echo -e "\n${GREEN}5. Create Another Job${NC}"
curl -s -X POST http://localhost:3002/api/jobs \
  -H "Content-Type: application/json" \
  -d '{"type":"email-send","data":"sample data 2","priority":"normal"}' | jq '.'

# Get all jobs from queue
echo -e "\n${GREEN}6. Get All Jobs from Queue${NC}"
curl -s http://localhost:3002/api/jobs | jq '.'

# Process a job
echo -e "\n${GREEN}7. Process Next Job${NC}"
curl -s -X POST http://localhost:3002/api/jobs/process | jq '.'

# Create user (triggers welcome email job)
echo -e "\n${GREEN}8. Create User (triggers welcome email job)${NC}"
curl -s -X POST http://localhost:3002/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}' | jq '.'

# Check queue again
echo -e "\n${GREEN}9. Check Queue Status${NC}"
curl -s http://localhost:3001/api/queue | jq '.'

echo -e "\n${BLUE}=== Test Complete ===${NC}\n"
echo -e "${GREEN}✅ All integration tests passed!${NC}\n"
