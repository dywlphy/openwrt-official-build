#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

echo "=========================================="
echo "OpenWrt 24.10 Official Stable Build"
echo "diy-part1.sh - 配置feeds源"
echo "=========================================="

# ============================================
# 配置feeds源（不加PassWall feed）
# ============================================
echo "[1/3] 配置feeds源..."

cat > feeds.conf << 'EOF'
src-git packages https://github.com/openwrt/packages.git;openwrt-24.10
src-git luci https://github.com/openwrt/luci.git;openwrt-24.10
src-git printing https://github.com/dywlphy/openwrt-feed-printing.git;main
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
