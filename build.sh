#!/bin/bash
set -e

echo "🔨 Building Zig project for x86_64-linux-musl..."
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl
echo "✅ Build completed!"
