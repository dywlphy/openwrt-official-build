#!/bin/bash
echo "===== 配置 feeds 源  ====="
> feeds.conf
# 官方源
echo "src-git packages https://github.com/openwrt/packages.git;openwrt-24.10" >> feeds.conf
echo "src-git luci https://github.com/openwrt/luci.git;openwrt-24.10" >> feeds.conf
# 第三方源
echo "src-git smpackage https://github.com/dywlphy/small-package" >> feeds.conf
echo "src-git immortalwrt https://github.com/immortalwrt/packages" >> feeds.conf
# 打印源
echo "src-git printing https://github.com/dywlphy/openwrt-feed-printing" >> feeds.conf
echo "src-git hplipfeed https://github.com/woniuzfb/openwrt-24-printing-packages" >> feeds.conf
echo "✅ feeds.conf 配置完成（7个源）"
