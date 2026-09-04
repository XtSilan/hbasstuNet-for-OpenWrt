#!/bin/bash
set -e

# Optional proxy settings can be supplied by the caller (for example, build.bat).
# Do not hard-code a workstation-only proxy so this script also works in CI.

# Use stable 24.10.0 release (produces IPK packages)
export VERSION_PATH="${VERSION_PATH:-releases/24.10.0}"

cd /builder

# Initialize SDK if needed
if [ ! -d ./scripts ]; then
    ./setup.sh
fi

echo "=== Updating feeds ==="
./scripts/feeds update -a
./scripts/feeds install -a

echo "=== Configuring build ==="
make defconfig

echo "=== Copying package ==="
cp -a /package ./package/luci-app-hbasstunet

echo "=== Building package ==="
make package/luci-app-hbasstunet/compile V=s -j4

echo "=== Finding built packages ==="
find bin/packages -name 'luci-app-hbasstunet*' -exec cp {} /output/ \;

echo "=== BUILD COMPLETE ==="
ls -la /output/ 2>/dev/null || echo "No package files found in output."
