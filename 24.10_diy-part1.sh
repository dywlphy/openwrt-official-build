#!/bin/bash
#
# diy-part1.sh - 配置feeds源（在Update feeds之前执行）
# OpenWrt 24.10 版本
#

echo "=========================================="
echo "OpenWrt 24.10 Official Stable Build"
echo "diy-part1.sh - 配置feeds源"
echo "=========================================="

# 配置feeds源
echo "[1/3] 配置feeds源..."

cat > feeds.conf << 'EOF'
src-git packages https://github.com/openwrt/packages.git;openwrt-24.10
src-git luci https://github.com/openwrt/luci.git;openwrt-24.10
src-git printing https://github.com/dywlphy/openwrt-feed-printing.git;main
src-git timecontrol https://github.com/sirpdboy/luci-app-timecontrol
src-git frp https://github.com/kuoruan/openwrt-frp.git
src-git luci-app-frpc https://github.com/kuoruan/luci-app-frpc.git
EOF

echo "[2/3] 当前feeds配置:"
cat feeds.conf

echo ""
echo "[3/3] OpenWrt版本信息:"
echo "Branch: openwrt-24.10"
echo "Target: Official Stable"

echo ""
echo "=========================================="
echo "diy-part1.sh 执行完成"
echo "=========================================="
