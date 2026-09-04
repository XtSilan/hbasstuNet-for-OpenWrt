@echo off
setlocal

echo ============================================
echo   luci-app-hbasstunet Docker Build (IPK)
echo ============================================
echo.

docker --version >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not installed or not in PATH.
    exit /b 1
)

if not exist "output" mkdir output
docker rm -f openwrt-builder >nul 2>&1

echo [1/3] Creating build container...
docker create --name openwrt-builder -v "%CD%:/package" -v "%CD%/output:/output" -e "HBASSTUNET_VERSION=1.3.0" openwrt/sdk:x86_64 bash /package/build.sh >nul
if errorlevel 1 (
    echo Error: unable to create OpenWrt SDK container.
    exit /b 1
)

echo [2/3] Building...
docker start -a openwrt-builder
if errorlevel 1 (
    echo Error: OpenWrt SDK build failed.
    docker rm -f openwrt-builder >nul 2>&1
    exit /b 1
)

echo [3/3] Validating output package...
dir /b "output\luci-app-hbasstunet_1.3.0-*.ipk" >nul 2>&1
if errorlevel 1 (
    echo Error: no version 1.3.0 IPK was produced.
    docker rm -f openwrt-builder >nul 2>&1
    exit /b 1
)

docker rm openwrt-builder >nul 2>&1
echo.
echo Build complete:
dir /b "output\luci-app-hbasstunet_1.3.0-*.ipk"
echo.
echo Install with:
echo   opkg install /tmp/luci-app-hbasstunet_1.3.0-*.ipk
exit /b 0
