#!/bin/bash
#
# Start Jitsi Multitrack Recording Server - LOCALHOST MODE
#

set -e

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}Starting Jitsi - LOCALHOST MODE${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}No .env file found. Checking for .env.localhost...${NC}"
    if [ -f ".env.localhost" ]; then
        echo -e "${BLUE}Copying .env.localhost to .env${NC}"
        cp .env.localhost .env
    else
        echo -e "${RED}Error: No configuration file found!${NC}"
        echo ""
        echo "Please run the setup script first:"
        echo "  ./scripts/generate-passwords.sh localhost"
        echo ""
        exit 1
    fi
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

# Set proper permissions (ignore errors for files owned by Docker)
chmod -R 755 recordings 2>/dev/null || true
chmod -R 755 config 2>/dev/null || true

echo -e "${BLUE}ℹ Starting Jitsi services in LOCALHOST mode...${NC}"
echo ""

# Pull latest images
echo -e "${YELLOW}Pulling Docker images...${NC}"
docker-compose pull

echo ""
echo -e "${YELLOW}Starting containers with localhost configuration...${NC}"

# Start services with localhost override
docker-compose -f docker-compose.yml -f docker-compose.localhost.yml up -d

# Wait for web container to generate config
echo ""
echo -e "${YELLOW}Waiting for config generation...${NC}"
sleep 5

# Note: Keeping HTTPS/WSS for localhost (browser will use self-signed cert)
# No protocol fix needed - using secure protocols even on localhost

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
echo -e "${GREEN}Jitsi is now running (LOCALHOST)!${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

echo "Access Jitsi Meet at:"
echo -e "  ${GREEN}http://localhost:8000${NC}"
echo ""
echo "Recordings location:"
echo -e "  ${GREEN}$(pwd)/recordings/${NC}"
echo ""
echo "Useful commands:"
echo "  • View logs: docker-compose logs -f"
echo "  • View recorder logs: docker-compose logs -f recorder"
echo "  • Stop server: docker-compose down"
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

echo -e "${YELLOW}NOTE: This is LOCALHOST mode. For production deployment, use:${NC}"
echo -e "  ${BLUE}./scripts/start-production.sh${NC}"
echo ""
