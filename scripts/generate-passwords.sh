#!/bin/bash
#
# Generate random secure passwords for Jitsi components
# This script creates a .env file from .env.example with random passwords
#

set -e

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}Jitsi Multitrack Recording Setup${NC}"
echo -e "${BLUE}Password Generation Script${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

# Check if .env already exists
if [ -f ".env" ]; then
    echo -e "${RED}Warning: .env file already exists!${NC}"
    read -p "Do you want to overwrite it? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Aborting."
        exit 1
    fi
    echo "Backing up existing .env to .env.backup"
    cp .env .env.backup
fi

# Check if .env.example exists
if [ ! -f ".env.example" ]; then
    echo -e "${RED}Error: .env.example not found!${NC}"
    exit 1
fi

# Function to generate a random password
generate_password() {
    openssl rand -hex 32
}

echo "Generating secure random passwords..."
echo ""

# Generate passwords
JICOFO_COMPONENT_SECRET=$(generate_password)
JICOFO_AUTH_PASSWORD=$(generate_password)
JVB_AUTH_PASSWORD=$(generate_password)
JIBRI_RECORDER_PASSWORD=$(generate_password)

# Create .env from .env.example
cp .env.example .env

# Replace CHANGEME values with generated passwords
sed -i "s/CHANGEME_JICOFO_COMPONENT_SECRET/${JICOFO_COMPONENT_SECRET}/" .env
sed -i "s/CHANGEME_JICOFO_AUTH_PASSWORD/${JICOFO_AUTH_PASSWORD}/" .env
sed -i "s/CHANGEME_JVB_AUTH_PASSWORD/${JVB_AUTH_PASSWORD}/" .env
sed -i "s/CHANGEME_JIBRI_RECORDER_PASSWORD/${JIBRI_RECORDER_PASSWORD}/" .env

echo -e "${GREEN}✓ Passwords generated successfully!${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  - JICOFO_COMPONENT_SECRET: ******** (hidden)"
echo "  - JICOFO_AUTH_PASSWORD: ******** (hidden)"
echo "  - JVB_AUTH_PASSWORD: ******** (hidden)"
echo "  - JIBRI_RECORDER_PASSWORD: ******** (hidden)"
echo ""
echo -e "${GREEN}The .env file has been created with secure passwords.${NC}"
echo ""

# Prompt for PUBLIC_URL
read -p "Enter your PUBLIC_URL (default: http://localhost:8000): " PUBLIC_URL
PUBLIC_URL=${PUBLIC_URL:-http://localhost:8000}
sed -i "s|PUBLIC_URL=http://localhost:8000|PUBLIC_URL=${PUBLIC_URL}|" .env

echo ""
echo -e "${GREEN}✓ PUBLIC_URL set to: ${PUBLIC_URL}${NC}"
echo ""

# Prompt for AUTO RECORDING
read -p "Enable automatic recording when meetings start? (yes/no, default: yes): " AUTO_REC
if [[ $AUTO_REC =~ ^[Nn][Oo]$ ]]; then
    sed -i "s/ENABLE_AUTO_RECORDING=1/ENABLE_AUTO_RECORDING=0/" .env
    echo -e "${BLUE}ℹ Auto-recording disabled (manual control)${NC}"
else
    echo -e "${GREEN}✓ Auto-recording enabled${NC}"
fi

echo ""
echo -e "${BLUE}==================================${NC}"
echo -e "${GREEN}Setup complete!${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Review .env file and adjust settings if needed"
echo "  2. Run: ./scripts/start-server.sh to start Jitsi"
echo "  3. Access Jitsi at: ${PUBLIC_URL}"
echo "  4. Recordings will be stored in: ./recordings/"
echo ""
