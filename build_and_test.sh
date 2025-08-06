#!/bin/bash
set -e

echo "🔨 Building Zig project..."
zig build -Doptimize=ReleaseFast

echo "✅ Build completed!"
echo ""
echo "📦 Binary location: zig-out/bin/rinha_de_backend_2025_zig"
echo "📊 Binary size:"
ls -lh zig-out/bin/rinha_de_backend_2025_zig

echo ""
echo "🚀 Ready to test!"
echo "Next steps:"
echo "  1. docker compose up -d"
echo "  2. Test endpoints on port 9999"
echo ""