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
echo "src-git brlaser https://github.com/pdewacht/brlaser.git" >> feeds.conf

echo "✅ feeds.conf 配置完成"

# 关键：更新 feeds 后删除 smpackage 中的冲突包
echo "===== 清理冲突包 ====="
rm -rf feeds/smpackage/curl 2>/dev/null || true
rm -rf feeds/smpackage/dbus 2>/dev/null || true
rm -rf feeds/smpackage/openssl 2>/dev/null || true
echo "  ✅ 冲突包已清理"
