#!/bin/bash
set -e

echo "🚚 Starting container..."

docker compose down
docker compose build --no-cache
docker compose up -d

echo "🎉 Container started!"

docker compose logs -f
