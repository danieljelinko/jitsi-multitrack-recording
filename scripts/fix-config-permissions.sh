#!/bin/bash
#
# Fix Config Permissions and Directory Issues
# This script cleans up incorrectly created config directories
#

set -e

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}Fixing Jitsi Config Issues${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script needs sudo privileges to fix permissions${NC}"
    echo -e "${YELLOW}Please run: sudo ./scripts/fix-config-permissions.sh${NC}"
    exit 1
fi

cd "$(dirname "$0")/.."

echo -e "${YELLOW}Stopping containers...${NC}"
docker-compose down || true

echo ""
echo -e "${YELLOW}Cleaning up incorrectly created config directories...${NC}"

# Fix web config.js if it's a directory
if [ -d "config/web/config.js" ]; then
    echo "  • Removing incorrect config.js directory"
    rm -rf config/web/config.js
fi

# Fix web interface_config.js if it's a directory
if [ -d "config/web/interface_config.js" ]; then
    echo "  • Fixing interface_config.js directory"
    # If there's a file inside, move it out first
    if [ -f "config/web/interface_config.js/interface_config.js" ]; then
        mv config/web/interface_config.js/interface_config.js config/web/interface_config.js.tmp
        rm -rf config/web/interface_config.js
        mv config/web/interface_config.js.tmp config/web/interface_config.js
    else
        rm -rf config/web/interface_config.js
    fi
fi

# Fix prosody config if it's a directory
if [ -d "config/prosody/prosody.cfg.lua" ]; then
    echo "  • Removing incorrect prosody.cfg.lua directory"
    rm -rf config/prosody/prosody.cfg.lua
fi

# Remove auto-generated config directories created by Docker
echo ""
echo -e "${YELLOW}Cleaning up Docker-generated config directories...${NC}"
rm -rf config/web/config.js 2>/dev/null || true
rm -rf config/web/interface_config.js 2>/dev/null || true
rm -rf config/prosody/prosody.cfg.lua 2>/dev/null || true

# Fix ownership of all config files
echo ""
echo -e "${YELLOW}Fixing ownership of config directories...${NC}"
chown -R $SUDO_USER:$SUDO_USER config/ 2>/dev/null || true
chown -R $SUDO_USER:$SUDO_USER recordings/ 2>/dev/null || true

# Fix permissions
echo -e "${YELLOW}Fixing permissions...${NC}"
chmod -R 755 config/
chmod -R 755 recordings/

echo ""
echo -e "${GREEN}✓ Config cleanup complete!${NC}"
echo ""
echo -e "${BLUE}==================================${NC}"
echo -e "${GREEN}Ready to start${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""
echo "You can now start the server:"
echo -e "  ${GREEN}./scripts/start-server.sh${NC}"
echo ""
