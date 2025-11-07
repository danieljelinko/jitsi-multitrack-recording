#!/bin/bash
#
# Start Jitsi Multitrack Recording Server
#

set -e

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}Starting Jitsi Multitrack Recording${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo ""
    echo "Please run the setup script first:"
    echo "  ./scripts/generate-passwords.sh"
    echo ""
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose not found!${NC}"
    echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running!${NC}"
    echo "Please start Docker and try again."
    exit 1
fi

# Create recordings directory if it doesn't exist
mkdir -p recordings

# Set proper permissions
chmod -R 755 recordings
chmod -R 755 config

echo -e "${BLUE}ℹ Starting Jitsi services...${NC}"
echo ""

# Pull latest images
echo -e "${YELLOW}Pulling Docker images...${NC}"
docker-compose pull

echo ""
echo -e "${YELLOW}Starting containers...${NC}"

# Start services
docker-compose up -d

echo ""
echo -e "${GREEN}✓ Services started successfully!${NC}"
echo ""

# Wait for services to be ready
echo -e "${BLUE}ℹ Waiting for services to be ready...${NC}"
sleep 5

# Check service status
echo ""
echo -e "${BLUE}Service Status:${NC}"
docker-compose ps

echo ""
echo -e "${BLUE}==================================${NC}"
echo -e "${GREEN}Jitsi is now running!${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

# Get PUBLIC_URL from .env
PUBLIC_URL=$(grep "^PUBLIC_URL=" .env | cut -d '=' -f2)

echo "Access Jitsi Meet at:"
echo -e "  ${GREEN}${PUBLIC_URL}${NC}"
echo ""
echo "Recordings location:"
echo -e "  ${GREEN}$(pwd)/recordings/${NC}"
echo ""
echo "Useful commands:"
echo "  • View logs: docker-compose logs -f"
echo "  • View recorder logs: docker-compose logs -f recorder"
echo "  • Stop server: ./scripts/stop-server.sh"
echo "  • Restart server: docker-compose restart"
echo ""
echo "To create a meeting, open the URL above and enter a room name."
echo ""

# Check if auto-recording is enabled
AUTO_REC=$(grep "^ENABLE_AUTO_RECORDING=" .env | cut -d '=' -f2)
if [ "$AUTO_REC" = "1" ]; then
    echo -e "${GREEN}✓ Auto-recording is ENABLED${NC}"
    echo "  Meetings will be automatically recorded when started."
else
    echo -e "${YELLOW}ℹ Auto-recording is DISABLED${NC}"
    echo "  Use the recording controls in the meeting to start recording."
fi
echo ""
