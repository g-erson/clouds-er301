#!/bin/bash
# Build clouds for AM335x (real ER-301 hardware)
# Uses pre-built Docker image with TI SDK already installed
# Works on Apple Silicon via x86_64 emulation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="tomjfiset/er-301-am335x-build-env:1.1.2"

echo "Building clouds for AM335x using $IMAGE_NAME..."
echo "(This uses x86_64 emulation on ARM Mac, so it may be slow)"
echo ""

# Ensure symlinks point to correct locations for Docker mount
cd "$SCRIPT_DIR/mods/clouds"

# Run the build in Docker
# Mount paths match the GitHub Actions setup
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/workspace/clouds-er301" \
    -v "$SCRIPT_DIR/../er-301-custom-units:/workspace/er-301" \
    -v "$SCRIPT_DIR/../mi-eurorack:/workspace/mi-eurorack" \
    -w /workspace/clouds-er301/mods/clouds \
    "$IMAGE_NAME" \
    bash -c "
        # Setup symlinks inside container
        rm -f scripts hal er-301 mi
        ln -sf /workspace/er-301/scripts scripts
        ln -sf /workspace/er-301/arch/am335x/hal hal
        ln -sf /workspace/er-301 er-301
        ln -sf /workspace/mi-eurorack mi
        
        # Build
        make clouds ARCH=am335x PROFILE=release -j\$(nproc)
    "

echo ""
echo "Build complete! Package is at:"
ls -la "$SCRIPT_DIR/mods/clouds/release/am335x/"*.pkg 2>/dev/null || echo "  (check mods/clouds/release/am335x/ directory)"
echo ""
echo "Copy this to your ER-301 SD card at /ER-301/packages/"
