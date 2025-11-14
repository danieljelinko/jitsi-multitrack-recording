#!/bin/bash
#
# View logs from Jitsi services
#

# Color output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}Jitsi Multitrack Recording - Logs${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

if [ $# -eq 0 ]; then
    echo "Usage: $0 [service]"
    echo ""
    echo "Available services:"
    echo "  • all       - All services"
    echo "  • web       - Jitsi Meet web interface"
    echo "  • prosody   - XMPP server"
    echo "  • jicofo    - Conference focus"
    echo "  • jvb       - Jitsi Videobridge"
    echo "  • recorder  - Multitrack recorder"
    echo ""
    echo "Example:"
    echo "  $0 recorder    # View recorder logs"
    echo "  $0 all         # View all logs"
    echo ""
    exit 1
fi

SERVICE=$1

case "$SERVICE" in
    all)
        echo -e "${GREEN}Showing logs from all services (Ctrl+C to exit)${NC}"
        echo ""
        docker-compose logs -f
        ;;
    web|prosody|jicofo|jvb|recorder)
        echo -e "${GREEN}Showing logs from $SERVICE (Ctrl+C to exit)${NC}"
        echo ""
        docker-compose logs -f "$SERVICE"
        ;;
    *)
        echo "Unknown service: $SERVICE"
        echo "Run without arguments to see available services."
        exit 1
        ;;
esac
