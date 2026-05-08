#!/bin/bash
# ==========================================
# diy-part1.sh - 配置 Feed 源
# ==========================================

echo "===== 配置 feeds ====="

# 创建 feeds.conf.default，使用 master-0123 的 printing 源
cat > feeds.conf.default <<'EOF'
src-git printing https://github.com/master-0123/openwrt-printing-packages.git;main
src-git kenzo https://github.com/kenzok8/openwrt-packages.git
src-git small https://github.com/kenzok8/small.git
src-git smpackage https://github.com/kenzok8/small-package
src-git helloworld https://github.com/fw876/helloworld
src-git immortalwrt https://github.com/immortalwrt/packages.git;openwrt-24.10
EOF

echo "  已创建 feeds.conf.default"
echo "  1. printing    - CUPS 打印包源（master-0123，优先级最高）"
echo "  2. kenzo       - 常用软件包"
echo "  3. small       - 科学上网相关"
echo "  4. smpackage   - 小型软件包集合"
echo "  5. helloworld  - SSR-Plus 源"
echo "  6. immortalwrt - ImmortalWrt 软件包"
echo ""
echo "注意：printing 在 smpackage 之前，确保 cups 包使用 printing 源版本"
