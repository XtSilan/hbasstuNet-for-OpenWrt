@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   luci-app-hbasstunet Docker Build (IPK)
echo ============================================
echo.

REM Check if Docker is available
docker --version >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not installed or not in PATH.
    exit /b 1
)

REM Create output directory
if not exist "output" mkdir output

REM Remove old container if exists
docker rm -f openwrt-builder 2>nul

REM Create container
echo [1/3] Creating build container...
docker create --name openwrt-builder -v "%CD%:/package" -e "http_proxy=http://host.docker.internal:7890" -e "https_proxy=http://host.docker.internal:7890" -e "HTTP_PROXY=http://host.docker.internal:7890" -e "HTTPS_PROXY=http://host.docker.internal:7890" -e "no_proxy=*zhihu.com;*zhimg.com;*jd.com;100ime-iat-api.xfyun.cn;*360buyimg.com;localhost;*.local;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.2*;172.30.*;172.31.*;192.168.*" -e "NO_PROXY=*zhihu.com;*zhimg.com;*jd.com;100ime-iat-api.xfyun.cn;*360buyimg.com;localhost;*.local;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.2*;172.30.*;172.31.*;192.168.*" openwrt/sdk:x86_64 bash /package/build.sh

REM Start build
echo [2/3] Building (first run ~10 min, cached runs ~3 min)...
docker start -a openwrt-builder

REM Extract IPK via docker cp
echo [3/3] Extracting IPK package...
docker cp openwrt-builder:/builder/bin/packages/x86_64/base/luci-app-hbasstunet_1_x86_64.ipk "%CD%\output\" 2>nul
docker cp openwrt-builder:/builder/bin/packages/x86_64/base/luci-app-hbasstunet_*.ipk "%CD%\output\" 2>nul

REM Cleanup
docker rm openwrt-builder 2>nul

echo.
echo ============================================
echo   Build Complete!
echo ============================================
echo.
echo Output:
dir /b "%CD%\output\*.ipk" 2>nul
echo.
echo Install on router:
echo   scp output\luci-app-hbasstunet_1_x86_64.ipk root@192.168.1.1:/tmp/
echo   ssh root@192.168.1.1
echo   opkg install /tmp/luci-app-hbasstunet_1_x86_64.ipk
echo.
pause
