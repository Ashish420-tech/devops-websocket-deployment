#!/bin/bash

set -e

echo "====================================="
echo " Fixing DevOps Assignment"
echo "====================================="

# -----------------------------
# 1. Fix docker-compose.yml
# -----------------------------
echo "[1/3] Fixing docker-compose.yml..."

sed -i 's|# - ./frontend:/usr/share/nginx/html:ro|      - ./frontend:/usr/share/nginx/html:ro|' docker-compose.yml

# -----------------------------
# 2. Fix nginx.conf
# -----------------------------
echo "[2/3] Fixing nginx.conf..."

sed -i 's|proxy_pass http://localhost:8000/ws;|proxy_pass http://backend:8000/ws;|' nginx.conf

sed -i 's|# proxy_set_header Upgrade \$http_upgrade;|proxy_set_header Upgrade \$http_upgrade;|' nginx.conf

sed -i 's|# proxy_set_header Connection "upgrade";|proxy_set_header Connection "upgrade";|' nginx.conf

# -----------------------------
# 3. Restart containers
# -----------------------------
echo "[3/3] Restarting Docker..."

docker compose down

docker compose up -d --build

echo
echo "====================================="
echo " Configuration fixed successfully"
echo "====================================="

docker compose ps
