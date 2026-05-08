#!/bin/bash
# ==========================================
# feeds 配置：官方默认源 + kenzok8 + helloworld + immortalwrt + openwrt-cups
# 注意：源顺序决定优先级，官方源应保持最高优先级
# ==========================================

echo "===== 配置 feeds 源 ====="

cp feeds.conf.default feeds.conf.default.bak

echo "src-git kenzo https://github.com/kenzok8/openwrt-packages.git" >> feeds.conf.default
echo "src-git small https://github.com/kenzok8/small.git" >> feeds.conf.default
echo "src-git smpackage https://github.com/kenzok8/small-package" >> feeds.conf.default
echo "src-git helloworld https://github.com/fw876/helloworld" >> feeds.conf.default
echo "src-git immortalwrt https://github.com/immortalwrt/packages.git;openwrt-24.10" >> feeds.conf.default
echo "src-git cups https://github.com/op4packages/openwrt-cups.git" >> feeds.conf.default

echo "✅ feeds 源配置完成"
echo "已添加：kenzo, small, smpackage, helloworld, immortalwrt, cups"
