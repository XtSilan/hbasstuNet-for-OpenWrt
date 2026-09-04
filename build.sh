#!/bin/bash
set -e

# Proxy settings
export http_proxy=http://host.docker.internal:7890
export https_proxy=http://host.docker.internal:7890
export HTTP_PROXY=http://host.docker.internal:7890
export HTTPS_PROXY=http://host.docker.internal:7890
export no_proxy="localhost;*.local;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.2*;172.30.*;172.31.*;192.168.*"
export NO_PROXY="$no_proxy"

# Use stable 24.10.0 release (produces IPK packages)
export VERSION_PATH="releases/24.10.0"

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
