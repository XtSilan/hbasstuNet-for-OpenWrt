#!/bin/bash
set -e

# Optional proxy settings can be supplied by the caller (for example, build.bat).
# Do not hard-code a workstation-only proxy so this script also works in CI.

# Use stable 24.10.0 release (produces IPK packages)
export VERSION_PATH="${VERSION_PATH:-releases/24.10.0}"
export HBASSTUNET_VERSION="${HBASSTUNET_VERSION:-1.3.1}"

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
rm -rf ./package/luci-app-hbasstunet
cp -a /package ./package/luci-app-hbasstunet

echo "=== Building package ==="
find bin/packages -type f -name 'luci-app-hbasstunet_*.ipk' -delete 2>/dev/null || true
make package/luci-app-hbasstunet/compile V=s -j4

echo "=== Finding built packages ==="
package=$(find bin/packages -type f -name "luci-app-hbasstunet_${HBASSTUNET_VERSION}-*.ipk" -print -quit)
[ -n "$package" ] || { echo "No luci-app-hbasstunet IPK was produced." >&2; exit 1; }
rm -f /output/luci-app-hbasstunet_*.ipk
cp "$package" /output/
test -f "/output/$(basename "$package")"

echo "=== BUILD COMPLETE ==="
ls -la /output/ 2>/dev/null || echo "No package files found in output."
