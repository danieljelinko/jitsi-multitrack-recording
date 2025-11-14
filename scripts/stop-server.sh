#!/bin/bash
#
# Stop Jitsi Multitrack Recording Server
#

set -e

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}Stopping Jitsi Multitrack Recording${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose not found!${NC}"
    exit 1
fi

echo -e "${BLUE}ℹ Stopping all services...${NC}"
echo ""

# Stop services
docker-compose down

echo ""
echo -e "${GREEN}✓ All services stopped successfully!${NC}"
echo ""
echo "To start again, run: ./scripts/start-server.sh"
echo "To remove all data (including recordings), run: ./scripts/clean-all.sh"
echo ""
