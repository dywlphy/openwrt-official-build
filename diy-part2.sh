#!/bin/bash
# ==========================================
# diy-part2.sh -  自启动脚本 + 自动共享 + CUPS + GRUB修复
# OpenWrt 24 专用 - 方案三（精确拉取）
# ==========================================

# ==========================================
# 1. 修复 GRUB 超时为 0 秒
# ==========================================
echo "===== 修复 GRUB 超时为 0 秒 ====="
for cfg in target/linux/x86/image/grub-efi.cfg target/linux/x86/image/grub-pc.cfg target/linux/x86/image/grub-iso.cfg; do
    if [ -f "$cfg" ]; then
        sed -i 's/^set timeout=.*/set timeout=0/' "$cfg"
        echo "  ✅ $(basename $cfg): timeout=0"
    fi
done

# ==========================================
# 2. 修复 Makefile 问题（使用 find 动态查找）
# ==========================================
echo "===== 修复 Makefile 问题 ====="

# 修复 tiff
TIFF_MK=$(find feeds -path "*/tiff/Makefile" 2>/dev/null | head -1)
if [ -n "$TIFF_MK" ] && [ -f "$TIFF_MK" ]; then
    sed -i 's/--enable-webp/--disable-webp/g' "$TIFF_MK"
    echo "  ✅ tiff Makefile 已修复: $TIFF_MK"
fi

# 修复 ghostscript
GS_MK=$(find feeds -path "*/ghostscript/Makefile" 2>/dev/null | head -1)
if [ -n "$GS_MK" ] && [ -f "$GS_MK" ]; then
    sed -i 's/--enable-cups/--with-install-cups/g' "$GS_MK"
    echo "  ✅ ghostscript Makefile 已修复: $GS_MK"
fi

# 修复 cups Makefile（从 smpackage 源）
CUPS_MK=$(find feeds/smpackage -path "*/cups/Makefile" 2>/dev/null | head -1)
if [ -n "$CUPS_MK" ] && [ -f "$CUPS_MK" ]; then
    sed -i 's/DEPENDS:=/DEPENDS:=+libusb-1.0 +libstdcpp /' "$CUPS_MK"
    echo "  ✅ cups Makefile 已修复: $CUPS_MK"
fi

# ==========================================
# 3. 创建目录和文件
# ==========================================
echo "===== 创建目录和文件 ====="
mkdir -p files/etc/init.d files/etc/rc.d files/etc/avahi/services

# AirPrint 服务文件
cat > files/etc/avahi/services/cups.service << 'EOF'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h - CUPS</name>
  <service>
    <type>_ipp._tcp</type>
    <subtype>_universal._sub._ipp._tcp</subtype>
    <port>631</port>
    <txt-record>txtver=1</txt-record>
    <txt-record>qtotal=1</txt-record>
    <txt-record>Transparent=T</txt-record>
    <txt-record>URF=WFD</txt-record>
    <txt-record>Color=T</txt-record>
    <txt-record>Duplex=T</txt-record>
    <txt-record>Copies=T</txt-record>
  </service>
</service-group>
EOF
chmod 644 files/etc/avahi/services/cups.service
echo "  ✅ AirPrint 服务文件已创建"

# ==========================================
# 4. 服务自启动脚本
# ==========================================
echo "===== 创建服务自启动脚本 ====="
cat > files/etc/init.d/custom-autostart << 'EOF'
#!/bin/sh /etc/rc.common
START=99
start() {
    [ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd enable && /etc/init.d/cupsd start
    [ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon enable && /etc/init.d/avahi-daemon start
    [ -x /etc/init.d/ksmbd ] && /etc/init.d/ksmbd enable && /etc/init.d/ksmbd start
    [ -x /etc/init.d/miniupnpd ] && /etc/init.d/miniupnpd enable && /etc/init.d/miniupnpd start
    [ -x /etc/init.d/ddns ] && /etc/init.d/ddns enable && /etc/init.d/ddns start
    [ -x /etc/init.d/adblock ] && /etc/init.d/adblock enable && /etc/init.d/adblock start
    [ -x /etc/init.d/nlbwmon ] && /etc/init.d/nlbwmon enable && /etc/init.d/nlbwmon start
}
EOF
chmod +x files/etc/init.d/custom-autostart
ln -sf ../init.d/custom-autostart files/etc/rc.d/S99custom-autostart
echo "  ✅ 服务自启动脚本已创建"

# ==========================================
# 5. 自动共享脚本
# ==========================================
echo "===== 创建自动共享脚本 ====="
cat > files/etc/init.d/auto-share-init << 'EOF'
#!/bin/sh /etc/rc.common
START=98
boot() { sleep 15; start; }
start() {
    echo "开始自动探测可用存储空间..."
    root_dev="$(df -k / | awk 'NR==2{print $1}')"
    BEST_PART=""
    BEST_FREE=0
    TOTAL_KB=0
    IS_SYSTEM_PART=0
    for part in /mnt/*; do
        if mountpoint -q "$part" 2>/dev/null; then
            dev=$(df -k "$part" | awk 'NR==2{print $1}')
            total_kb=$(df -k "$part" | awk 'NR==2{print $2}')
            free_kb=$(df -k "$part" | awk 'NR==2{print $4}')
            if [ "$dev" != "$root_dev" ] && [ "$free_kb" -gt "$BEST_FREE" ]; then
                BEST_FREE=$free_kb
                TOTAL_KB=$total_kb
                BEST_PART=$part
                IS_SYSTEM_PART=0
            fi
        fi
    done
    if [ -z "$BEST_PART" ]; then
        for part in /overlay /; do
            if mountpoint -q "$part" 2>/dev/null; then
                free_kb=$(df -k "$part" | awk 'NR==2{print $4}')
                if [ "$free_kb" -gt "$BEST_FREE" ]; then
                    BEST_FREE=$free_kb
                    TOTAL_KB=$(df -k "$part" | awk 'NR==2{print $2}')
                    BEST_PART=$part
                    IS_SYSTEM_PART=1
                fi
            fi
        done
    fi
    if [ -z "$BEST_PART" ]; then
        echo "未找到可用存储分区，跳过共享配置。"
        return 0
    fi
    SHARE_DIR="$BEST_PART/OpenWrt_Share"
    mkdir -p "$SHARE_DIR"
    chmod 0777 "$SHARE_DIR"
    free_kb=$(df -k "$BEST_PART" | awk 'NR==2{print $4}')
    use_kb=$((free_kb * 60 / 100))
    echo "$use_kb" > "$SHARE_DIR/.size_limit_kb"
    while uci delete ksmbd.@share[0] 2>/dev/null; do :; done
    uci add ksmbd share
    uci set ksmbd.@share[-1].name='Auto_Share'
    uci set ksmbd.@share[-1].path="$SHARE_DIR"
    uci set ksmbd.@share[-1].browseable='yes'
    uci set ksmbd.@share[-1].read_only='no'
    uci set ksmbd.@share[-1].guest_ok='yes'
    uci set ksmbd.@share[-1].force_directory_mode='0777'
    uci set ksmbd.@share[-1].force_create_mode='0666'
    uci commit ksmbd
    /etc/init.d/ksmbd restart
    TOTAL_MB=$((TOTAL_KB / 1024))
    SHARE_MB=$((use_kb / 1024))
    echo "自动共享配置完成！" > "$SHARE_DIR/README.txt"
    echo "分区：$BEST_PART (总容量约 ${TOTAL_MB}MB)" >> "$SHARE_DIR/README.txt"
    echo "类型：$([ "$IS_SYSTEM_PART" -eq 0 ] && echo '外部存储' || echo '系统分区')" >> "$SHARE_DIR/README.txt"
    echo "共享空间上限(60%剩余空间)：${SHARE_MB}MB" >> "$SHARE_DIR/README.txt"
    echo "自动共享初始化完成：$SHARE_DIR"
}
stop() {
    echo "auto-share-init stopped."
}
EOF
chmod +x files/etc/init.d/auto-share-init
ln -sf ../init.d/auto-share-init files/etc/rc.d/S98auto-share-init
echo "  ✅ 自动共享脚本已创建"

# ==========================================
# 6. 安装中文语言包（精确安装）
# ==========================================
echo "===== 安装中文语言包 ====="
./scripts/feeds install luci-i18n-base-zh-cn && echo "  ✅ luci-i18n-base-zh-cn" || echo "  ⚠️ luci-i18n-base-zh-cn 失败"
./scripts/feeds install luci-i18n-firewall-zh-cn && echo "  ✅ luci-i18n-firewall-zh-cn" || echo "  ⚠️ luci-i18n-firewall-zh-cn 失败"
./scripts/feeds install luci-i18n-opkg-zh-cn && echo "  ✅ luci-i18n-opkg-zh-cn" || echo "  ⚠️ luci-i18n-opkg-zh-cn 失败"
./scripts/feeds install luci-i18n-upnp-zh-cn && echo "  ✅ luci-i18n-upnp-zh-cn" || echo "  ⚠️ luci-i18n-upnp-zh-cn 失败"
./scripts/feeds install luci-i18n-ddns-zh-cn && echo "  ✅ luci-i18n-ddns-zh-cn" || echo "  ⚠️ luci-i18n-ddns-zh-cn 失败"
./scripts/feeds install luci-i18n-sqm-zh-cn && echo "  ✅ luci-i18n-sqm-zh-cn" || echo "  ⚠️ luci-i18n-sqm-zh-cn 失败"
./scripts/feeds install luci-i18n-wol-zh-cn && echo "  ✅ luci-i18n-wol-zh-cn" || echo "  ⚠️ luci-i18n-wol-zh-cn 失败"
./scripts/feeds install luci-i18n-nft-qos-zh-cn && echo "  ✅ luci-i18n-nft-qos-zh-cn" || echo "  ⚠️ luci-i18n-nft-qos-zh-cn 失败"
./scripts/feeds install luci-i18n-attendedsysupgrade-zh-cn && echo "  ✅ luci-i18n-attendedsysupgrade-zh-cn" || echo "  ⚠️ luci-i18n-attendedsysupgrade-zh-cn 失败"
./scripts/feeds install luci-i18n-wireguard-zh-cn && echo "  ✅ luci-i18n-wireguard-zh-cn" || echo "  ⚠️ luci-i18n-wireguard-zh-cn 失败"
./scripts/feeds install luci-i18n-ttyd-zh-cn && echo "  ✅ luci-i18n-ttyd-zh-cn" || echo "  ⚠️ luci-i18n-ttyd-zh-cn 失败"
./scripts/feeds install luci-i18n-ssr-plus-zh-cn && echo "  ✅ luci-i18n-ssr-plus-zh-cn" || echo "  ⚠️ luci-i18n-ssr-plus-zh-cn 失败"
./scripts/feeds install luci-i18n-cupsd-zh-cn && echo "  ✅ luci-i18n-cupsd-zh-cn" || echo "  ⚠️ luci-i18n-cupsd-zh-cn 失败"
./scripts/feeds install luci-i18n-adblock-zh-cn && echo "  ✅ luci-i18n-adblock-zh-cn" || echo "  ⚠️ luci-i18n-adblock-zh-cn 失败"
./scripts/feeds install luci-i18n-nlbwmon-zh-cn && echo "  ✅ luci-i18n-nlbwmon-zh-cn" || echo "  ⚠️ luci-i18n-nlbwmon-zh-cn 失败"
./scripts/feeds install luci-i18n-commands-zh-cn && echo "  ✅ luci-i18n-commands-zh-cn" || echo "  ⚠️ luci-i18n-commands-zh-cn 失败"
./scripts/feeds install luci-i18n-watchcat-zh-cn && echo "  ✅ luci-i18n-watchcat-zh-cn" || echo "  ⚠️ luci-i18n-watchcat-zh-cn 失败"
./scripts/feeds install luci-i18n-autoreboot-zh-cn 2>/dev/null && echo "  ✅ luci-i18n-autoreboot-zh-cn" || echo "  ⚠️ luci-i18n-autoreboot-zh-cn 失败"

# ==========================================
# 8. 安装 avahi（网络打印机发现）
# ==========================================
echo "===== 安装 avahi ====="
./scripts/feeds install avahi-dbus-daemon && echo "  ✅ avahi-dbus-daemon" || {
    ./scripts/feeds install avahi-nodbus-daemon && echo "  ✅ avahi-nodbus-daemon" || echo "  ⚠️ avahi 失败"
}

# ==========================================
# 9. 安装 ksmbd 相关（文件共享）
# ==========================================
echo "===== 安装 ksmbd ====="
./scripts/feeds install ksmbd-server && echo "  ✅ ksmbd-server" || echo "  ⚠️ ksmbd-server 失败"
./scripts/feeds install ksmbd-utils && echo "  ✅ ksmbd-utils" || echo "  ⚠️ ksmbd-utils 失败"
./scripts/feeds install luci-app-ksmbd && echo "  ✅ luci-app-ksmbd" || echo "  ⚠️ luci-app-ksmbd 失败"

echo "✅ diy-part2.sh 执行完成"
