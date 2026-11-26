#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Installing Docker & Docker Compose..."
sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose-v2 curl
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER" || true

echo "[2/4] Creating local .env from .env.example (if missing)..."
if [ ! -f .env ]; then
  cp .env.example .env
fi

echo "[3/4] Building and starting booking_web + booking_db..."
sudo docker compose up -d --build

echo "[4/4] Waiting for /health..."
sleep 6
curl -fsS http://localhost/health && echo ""
echo "Done! Running containers:"
sudo docker ps
