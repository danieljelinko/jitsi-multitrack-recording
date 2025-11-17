#!/bin/bash
#
# Fix localhost config.js to use HTTP instead of HTTPS
#

set -e

echo "Fixing config.js to use HTTP/WS instead of HTTPS/WSS for localhost..."

# Stop web container
docker-compose stop web

# Fix the config.js file
sed -i "s|'https://localhost:8000/'|'http://localhost:8000/'|g" config/web/config.js
sed -i "s|'wss://localhost:8000/'|'ws://localhost:8000/'|g" config/web/config.js

# Restart web container
docker-compose start web

echo "Fixed! Waiting for web container to start..."
sleep 3

# Verify
echo ""
echo "Verifying config..."
curl -s http://localhost:8000/config.js | grep -E "bosh|websocket"

echo ""
echo "Done! Try joining a meeting now."
