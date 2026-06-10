#!/bin/bash
# Build clouds for AM335x (real ER-301 hardware)
# Uses pre-built Docker image with TI SDK already installed
# Works on Apple Silicon via x86_64 emulation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building clouds for AM335x..."
echo "(This uses x86_64 emulation on ARM Mac, so it may be slow)"
echo ""

# Just use make release which handles Docker
cd "$SCRIPT_DIR"
make release

echo ""
echo "Build complete! Package is at:"
ls -la "$SCRIPT_DIR/release/am335x/"*.pkg 2>/dev/null || echo "  (check release/am335x/ directory)"
echo ""
echo "Copy this to your ER-301 SD card at /ER-301/packages/"
