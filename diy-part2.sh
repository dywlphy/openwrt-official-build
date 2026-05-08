#!/bin/bash
# ============================================================
# diy-part2.sh - 自定义修改脚本
# 在 config.txt 应用之后、make defconfig 之前执行
# ============================================================

echo "=========================================="
echo "【diy-part2.sh 开始执行】"
echo "=========================================="

# ============================================================
# 1. GRUB 超时修正（修改 grub-efi.cfg 源文件模板）
# ============================================================
echo ""
echo "【修正 GRUB 超时为 0】"
sed -i 's/set timeout=.*/set timeout=0/' target/linux/x86/image/grub-efi.cfg 2>/dev/null || true
sed -i 's/set timeout=.*/set timeout=0/' target/linux/x86/image/grub-pc.cfg 2>/dev/null || true
sed -i 's/set timeout=.*/set timeout=0/' target/linux/x86/image/grub-iso.cfg 2>/dev/null || true
echo "GRUB 超时已设置为 0"

# ============================================================
# 2. CUPS 打印包安装确认
# ============================================================
echo ""
echo "【安装 CUPS 打印相关包】"

# printing 源的包（跳过 qpdf/poppler/openprinting-cups-filters，与 OpenWrt 24.10 不兼容）
# qpdf 依赖 libpcre（24.10 已移除），poppler 版本过旧，openprinting-cups-filters 依赖 qpdf
for pkg in cups cups-bjnp ghostscript splix \
           libcups libcupsimage cups-bsd cups-client cups-ppdc \
           lcms2 libijs libjbigkit ghostscript-fonts-std; do
    ./scripts/feeds install "$pkg" 2>/dev/null && echo "  OK $pkg" || echo "  WARN $pkg install failed"
done

# smpackage 的 luci-app-cupsd
./scripts/feeds install luci-app-cupsd 2>/dev/null && echo "  OK luci-app-cupsd" || echo "  WARN luci-app-cupsd install failed"

# 系统依赖包
for pkg in avahi avahi-dbus-daemon dbus fontconfig libfreetype libtiff libjpeg libpng libexpat glib2; do
    ./scripts/feeds install "$pkg" 2>/dev/null && echo "  OK $pkg" || echo "  WARN $pkg install failed"
done

# ============================================================
# 3. 自启动脚本
# ============================================================
echo ""
echo "【创建自定义自启动脚本】"

# ---- CUPS 自启动 ----
cat > files/etc/uci-defaults/99-cupsd <<'UCI_EOF'
#!/bin/sh
# 确保 CUPS 服务开机自启
/etc/init.d/cupsd enable 2>/dev/null
exit 0
UCI_EOF
echo "  OK cupsd 自启动脚本"

# ---- Avahi 自启动 ----
cat > files/etc/uci-defaults/99-avahi <<'UCI_EOF'
#!/bin/sh
# 确保 Avahi 服务开机自启
/etc/init.d/avahi-daemon enable 2>/dev/null
exit 0
UCI_EOF
echo "  OK avahi-daemon 自启动脚本"

# ---- D-Bus 自启动 ----
cat > files/etc/uci-defaults/99-dbus <<'UCI_EOF'
#!/bin/sh
# 确保 D-Bus 服务开机自启
/etc/init.d/dbus enable 2>/dev/null
exit 0
UCI_EOF
echo "  OK dbus 自启动脚本"

# ---- KSMBD 自启动 ----
cat > files/etc/uci-defaults/99-ksmbd <<'UCI_EOF'
#!/bin/sh
# 确保 KSMBD 服务开机自启
/etc/init.d/ksmbd enable 2>/dev/null
exit 0
UCI_EOF
echo "  OK ksmbd 自启动脚本"

# ---- MiniUPnPd 自启动 ----
cat > files/etc/uci-defaults/99-miniupnpd <<'UCI_EOF'
#!/bin/sh
# 确保 MiniUPnPd 服务开机自启
/etc/init.d/miniupnpd enable 2>/dev/null
exit 0
UCI_EOF
echo "  OK miniupnpd 自启动脚本"

# ---- DDNS 自启动 ----
cat > files/etc/uci-defaults/99-ddns <<'UCI_EOF'
#!/bin/sh
# 确保 DDNS 服务开机自启
/etc/init.d/ddns enable 2>/dev/null
exit 0
UCI_EOF
echo "  OK ddns 自启动脚本"

# ============================================================
# 4. 自动共享脚本（检测最大分区并创建 ksmbd 共享）
# ============================================================
echo ""
echo "【创建自动共享脚本】"

cat > files/etc/uci-defaults/99-auto-share <<'UCI_EOF'
#!/bin/sh

# 自动检测最大数据分区并创建 KSMBD 共享
SHARE_NAME="shared"
SHARE_PATH=""
MAX_SIZE=0

# 遍历所有挂载的分区，找到最大的数据分区
for mount_point in $(awk '$3 ~ /^ext4|^vfat|^ntfs|^exfat|^btrfs/ {print $2}' /proc/mounts 2>/dev/null); do
    # 跳过根文件系统和 tmpfs
    case "$mount_point" in
        /|/rom|/tmp|/overlay|/run) continue ;;
    esac

    # 获取分区大小（KB）
    size=$(df -k "$mount_point" 2>/dev/null | awk 'NR==2 {print $2}')
    if [ -n "$size" ] && [ "$size" -gt "$MAX_SIZE" ] 2>/dev/null; then
        MAX_SIZE=$size
        SHARE_PATH="$mount_point"
    fi
done

if [ -n "$SHARE_PATH" ]; then
    # 确保共享目录存在
    mkdir -p "${SHARE_PATH}/${SHARE_NAME}"

    # 配置 KSMBD 共享
    uci -q batch <<-EOF
        set samba4.${SHARE_NAME}=sambashare
        set samba4.${SHARE_NAME}.name='${SHARE_NAME}'
        set samba4.${SHARE_NAME}.path='${SHARE_PATH}/${SHARE_NAME}'
        set samba4.${SHARE_NAME}.read_only='no'
        set samba4.${SHARE_NAME}.guest_ok='yes'
        set samba4.${SHARE_NAME}.create_mask='0666'
        set samba4.${SHARE_NAME}.dir_mask='0777'
        set samba4.${SHARE_NAME}.force_root='1'
        set samba4.${SHARE_NAME}.browseable='yes'
EOF
    uci commit samba4

    # 重启 KSMBD 服务使配置生效
    /etc/init.d/ksmbd restart 2>/dev/null

    logger -t auto-share "KSMBD share '${SHARE_NAME}' created at ${SHARE_PATH}/${SHARE_NAME}"
fi

exit 0
UCI_EOF
echo "  OK 自动共享脚本"

# ============================================================
# 5. CUPS 打印机 Web 界面配置
# ============================================================
echo ""
echo "【配置 CUPS 打印机访问】"

cat > files/etc/uci-defaults/99-cups-web <<'UCI_EOF'
#!/bin/sh
# 允许局域网访问 CUPS Web 管理界面
# 修改 CUPS 配置以允许远程管理
if [ -f /etc/cups/cupsd.conf ]; then
    sed -i 's/^Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf 2>/dev/null
    sed -i 's/^#Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf 2>/dev/null
fi
exit 0
UCI_EOF
echo "  OK CUPS Web 界面配置"

# ============================================================
# 6. 防火墙规则（CUPS 和 Avahi）
# ============================================================
echo ""
echo "【配置防火墙规则】"

cat > files/etc/uci-defaults/99-firewall-printing <<'UCI_EOF'
#!/bin/sh
# CUPS 打印服务防火墙规则
uci -q batch <<-EOF
    set firewall.cups='rule'
    set firewall.cups.name='Allow-CUPS'
    set firewall.cups.src='lan'
    set firewall.cups.proto='tcp'
    set firewall.cups.dest_port='631'
    set firewall.cups.target='ACCEPT'

    set firewall.mdns='rule'
    set firewall.mdns.name='Allow-mDNS'
    set firewall.mdns.src='lan'
    set firewall.mdns.proto='udp'
    set firewall.mdns.dest_port='5353'
    set firewall.mdns.target='ACCEPT'
EOF
uci commit firewall
exit 0
UCI_EOF
echo "  OK 防火墙规则配置"

# ============================================================
# 7. 系统默认语言设置为中文
# ============================================================
echo ""
echo "【设置系统默认语言为中文】"

cat > files/etc/uci-defaults/99-lang-zh-cn <<'UCI_EOF'
#!/bin/sh
# 设置系统默认语言为简体中文
uci set luci.main.lang='zh_cn'
uci commit luci
exit 0
UCI_EOF
echo "  OK 默认语言设置为中文(zh_cn)"

echo ""
echo "=========================================="
echo "【diy-part2.sh 执行完毕】"
echo "=========================================="
