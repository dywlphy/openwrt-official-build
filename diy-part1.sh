#!/bin/bash
# ==========================================
# feeds 配置：第三方源 + 官方源（官方优先级最高）
# ==========================================

echo "===== 配置 feeds 源 ====="

# 清除旧的 feeds.conf，从零开始
> feeds.conf

# 先写官方 feeds（保证基础源正确）
echo "src-git packages https://github.com/openwrt/packages.git;openwrt-24.10" >> feeds.conf
echo "src-git luci https://github.com/openwrt/luci.git;openwrt-24.10" >> feeds.conf

# 再添加第三方 feeds
echo "src-git immortalwrt https://github.com/immortalwrt/packages.git;openwrt-24.10" >> feeds.conf
echo "src-git kenzo https://github.com/kenzok8/openwrt-packages.git" >> feeds.conf
echo "src-git small https://github.com/kenzok8/small.git" >> feeds.conf
echo "src-git smpackage https://github.com/kenzok8/small-package" >> feeds.conf
echo "src-git helloworld https://github.com/fw876/helloworld" >> feeds.conf
echo "src-git cups https://github.com/op4packages/openwrt-cups.git" >> feeds.conf

echo "✅ feeds.conf 配置完成"
echo "已添加："
echo "  - 官方: packages, luci (优先级高)"
echo "  - 第三方: immortalwrt, kenzo, small, smpackage, helloworld, cups"
