#!/bin/bash
# ============================================================
# diy-part1.sh - Feed 源配置x
# 在 feeds update 之前执行，配置自定义软件源
# ============================================================

echo "=========================================="
echo "【配置自定义 Feed 源】"
echo "=========================================="

# 备份原始 feeds.conf.default
cp feeds.conf.default feeds.conf.default.bak

# 清空并写入自定义 Feed 源
# 注意：printing 必须在 smpackage 之前，确保 cups 包优先使用 printing 源的版本
cat > feeds.conf.default <<'EOF'
src-git printing https://github.com/belphegor-belbel/openwrt-printing-packages.git
src-git kenzo https://github.com/kenzok8/openwrt-packages.git
src-git small https://github.com/kenzok8/small.git
src-git smpackage https://github.com/kenzok8/small-package
src-git helloworld https://github.com/fw876/helloworld
src-git immortalwrt https://github.com/immortalwrt/packages.git;openwrt-24.10
EOF

echo ""
echo "Feed 源配置完成："
echo "  1. printing    - CUPS 打印包源（优先级最高）"
echo "  2. kenzo       - kenzok8 扩展包"
echo "  3. small       - kenzok8 小型包"
echo "  4. smpackage   - kenzok8 小型包（含 luci-app-cupsd）"
echo "  5. helloworld  - SSR-Plus 代理"
echo "  6. immortalwrt - ImmortalWrt 兼容包"
echo ""
echo "注意：printing 在 smpackage 之前，确保 cups 包使用 printing 源版本"
echo "=========================================="
