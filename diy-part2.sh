#!/bin/bash
# ==========================================
# diy-part2.sh - 自启动脚本 + 自动共享 + CUPS 包安装 + GRUB修复
# OpenWrt 24 专用
# 修复：cups-bjnp cupsbackenddir 路径错误问题
# ==========================================

# ----- 修复 GRUB 超时为 0 秒 -----
echo "===== 修复 GRUB 超时为 0 秒 ====="
for cfg in target/linux/x86/image/grub-efi.cfg target/linux/x86/image/grub-pc.cfg target/linux/x86/image/grub-iso.cfg; do
    if [ -f "$cfg" ]; then
        sed -i 's/^set timeout=.*/set timeout=0/' "$cfg"
        echo "  ✅ 已修改 $(basename $cfg): timeout=0"
    fi
done

# ----- 修复 cups-bjnp Makefile 路径错误 -----
echo "===== 修复 cups-bjnp Makefile 路径错误 ====="
CUPSBJNP_MK="feeds/immortalwrt/utils/cups-bjnp/Makefile"
if [ -f "$CUPSBJNP_MK" ]; then
    # 修复错误的 cupsbackenddir 路径
    # 原错误路径：$(STAGING_DIR)/usr/include/cups
    # 正确路径：$(STAGING_DIR)/usr/lib/cups/backend
    sed -i 's|--with-cupsbackenddir=$(STAGING_DIR)/usr/include/cups|--with-cupsbackenddir=$(STAGING_DIR)/usr/lib/cups/backend|' "$CUPSBJNP_MK"
    echo "  ✅ 已修复 cups-bjnp cupsbackenddir 路径"
else
    echo "  ⚠️ 未找到 cups-bjnp Makefile，跳过修复"
fi

# ----- 创建自启动目录 -----
mkdir -p files/etc/init.d files/etc/rc.d

# ----- 创建 AirPrint 服务文件（avahi）-----
echo "===== 创建 AirPrint 服务文件 ====="
mkdir -p files/etc/avahi/services
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

# ----- 服务自启动脚本 -----
cat > files/etc/init.d/custom-autostart << 'EOF'
#!/bin/sh /etc/rc.common
START=99
start() {
    [ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd enable && /etc/init.d/cupsd start
    [ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon enable && /etc/init.d/avahi-daemon start
    [ -x /etc/init.d/ksmbd ] && /etc/init.d/ksmbd enable && /etc/init.d/ksmbd start
    [ -x /etc/init.d/miniupnpd ] && /etc/init.d/miniupnpd enable && /etc/init.d/miniupnpd start
    [ -x /etc/init.d/ddns ] && /etc/init.d/ddns enable && /etc/init.d/ddns start
}
EOF
chmod +x files/etc/init.d/custom-autostart
ln -sf ../init.d/custom-autostart files/etc/rc.d/S99custom-autostart
# ----- 自动共享脚本 -----
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
    echo "类型：$([ "$IS_SYSTEM_PART" -eq 0 ] && echo '外部存储' || echo '系统分区（未检测到外部存储，降级使用）')" >> "$SHARE_DIR/README.txt"
    echo "共享空间上限(60%剩余空间)：${SHARE_MB}MB" >> "$SHARE_DIR/README.txt"
    echo "自动共享初始化完成：$SHARE_DIR"
}
stop() {
    echo "auto-share-init stopped."
}
EOF
chmod +x files/etc/init.d/auto-share-init
ln -sf ../init.d/auto-share-init files/etc/rc.d/S98auto-share-init
# ==========================================
# 安装中文语言包（关键修复）
# ==========================================
echo "===== 安装中文语言包 ====="
./scripts/feeds install luci-i18n-base-zh-cn && echo "  ✅ luci-i18n-base-zh-cn 安装成功" || echo "  ⚠️ luci-i18n-base-zh-cn 安装失败"
./scripts/feeds install luci-i18n-firewall-zh-cn && echo "  ✅ luci-i18n-firewall-zh-cn 安装成功" || echo "  ⚠️ luci-i18n-firewall-zh-cn 安装失败"
./scripts/feeds install luci-i18n-opkg-zh-cn && echo "  ✅ luci-i18n-opkg-zh-cn 安装成功" || echo "  ⚠️ luci-i18n-opkg-zh-cn 安装失败"
./scripts/feeds install luci-i18n-upnp-zh-cn && echo "  ✅ luci-i18n-upnp-zh-cn 安装成功" || echo "  ⚠️ luci-i18n-upnp-zh-cn 安装失败"
./scripts/feeds install luci-i18n-ddns-zh-cn && echo "  ✅ luci-i18n-ddns-zh-cn 安装成功" || echo "  ⚠️ luci-i18n-ddns-zh-cn 安装失败"
./scripts/feeds install luci-i18n-sqm-zh-cn && echo "  ✅ luci-i18n-sqm-zh-cn 安装成功" || echo "  ⚠️ luci-i18n-sqm-zh-cn 安装失败"
./scripts/feeds install luci-i18n-wol-zh-cn && echo "  ✅ luci-i18n-wol-zh-cn 安装成功" || echo "  ⚠️ luci-i18n-wol-zh-cn 安装失败"
./scripts/feeds install luci-i18n-nft-qos-zh-cn && echo "  ✅ luci-i18n-nft-qos-zh-cn 安装成功" || echo "  ⚠️ luci-i18n-nft-qos-zh-cn 安装失败"
./scripts/feeds install luci-i18n-attendedsysupgrade-zh-cn && echo "  ✅ luci-i18n-attendedsysupgrade-zh-cn 安装成功" || echo "  ⚠️ luci-i18n-attendedsysupgrade-zh-cn 安装失败"
./scripts/feeds install luci-i18n-wireguard-zh-cn && echo "  ✅ luci-i18n-wireguard-zh-cn 安装成功" || echo "  ⚠️ luci-i18n-wireguard-zh-cn 安装失败"
./scripts/feeds install luci-i18n-ttyd-zh-cn && echo "  ✅ luci-i18n-ttyd-zh-cn 安装成功" || echo "  ⚠️ luci-i18n-ttyd-zh-cn 安装失败"

# ==========================================
# CUPS 相关包安装
# ==========================================
echo "===== 安装 CUPS 相关包 ====="
echo "从 openwrt-cups 源安装打印驱动包..."

# +++ 修改点 1：修复 ghostscript 编译参数（在安装前修复）+++
# 查找并修复 ghostscript Makefile
GS_MAKEFILE=$(find feeds -name "ghostscript" -type d 2>/dev/null | head -1)/Makefile
if [ -f "$GS_MAKEFILE" ]; then
    sed -i 's/--enable-cups/--with-install-cups/g' "$GS_MAKEFILE"
    echo "  🔧 ghostscript Makefile 已修复"
fi

./scripts/feeds install -f -p cups ghostscript && echo "  ✅ ghostscript 安装成功" || echo "  ⚠️ ghostscript 安装失败"

# +++ 修改点 2：如果 ghostscript 安装失败，尝试二次修复 +++
if ! grep -q "CONFIG_PACKAGE_ghostscript=y" .config 2>/dev/null; then
    echo "  🔧 尝试二次修复 ghostscript..."
    GS_MAKEFILE=$(find feeds -name "ghostscript" -type d 2>/dev/null | head -1)/Makefile
    if [ -f "$GS_MAKEFILE" ]; then
        sed -i 's/--enable-cups/--with-install-cups/g' "$GS_MAKEFILE"
        ./scripts/feeds install -f -p cups ghostscript 2>/dev/null
    fi
fi

./scripts/feeds install -f -p cups gutenprint 2>/dev/null && echo "  ✅ gutenprint 安装成功" || echo "  ⚠️ gutenprint 安装失败"
./scripts/feeds install -f -p cups foomatic-db 2>/dev/null && echo "  ✅ foomatic-db 安装成功" || echo "  ⚠️ foomatic-db 安装失败"
./scripts/feeds install -f -p cups foomatic-db-engine 2>/dev/null && echo "  ✅ foomatic-db-engine 安装成功" || echo "  ⚠️ foomatic-db-engine 安装失败"
echo "从 immortalwrt 源安装扩展包..."
./scripts/feeds install -f -p immortalwrt cups-bjnp 2>/dev/null && echo "  ✅ cups-bjnp 安装成功" || echo "  ⚠️ cups-bjnp 安装失败"
echo "从 smpackage 源安装 CUPS 核心包..."
./scripts/feeds install -f -p smpackage cups cups-filters dbus luci-app-cupsd 2>/dev/null && echo "  ✅ CUPS 核心包安装成功" || echo "  ⚠️ CUPS 核心包安装失败"
echo "从官方源安装 avahi..."
./scripts/feeds install avahi-dbus-daemon 2>/dev/null && echo "  ✅ avahi-dbus-daemon 安装成功" || {
    ./scripts/feeds install avahi-nodbus-daemon 2>/dev/null && echo "  ✅ avahi-nodbus-daemon 安装成功" || echo "  ⚠️ avahi 安装失败"
}

# 从 brlaser 源安装 Brother 驱动
echo "===== 安装 Brother 打印机驱动 ====="
if ./scripts/feeds update brlaser; then
    echo "  ✅ brlaser feed 更新成功"
    if ./scripts/feeds install brlaser; then
        echo "  ✅ brlaser 驱动安装成功"
    else
        echo "  ❌ brlaser 驱动安装失败"
        exit 1
    fi
else
    echo "  ❌ brlaser feed 更新失败"
    exit 1
fi

# 安装 HP 打印机驱动
echo "===== 安装 HP 打印机驱动 ====="
if ./scripts/feeds install -f -p cups hplip-ppds 2>/dev/null; then
    echo "  ✅ hplip-ppds 安装成功"
else
    echo "  ❌ hplip-ppds 安装失败"
    exit 1
fi
# +++ 追加：强制启用打印机驱动配置 +++
echo "===== 强制启用驱动配置 ====="
echo "CONFIG_PACKAGE_brlaser=y" >> .config
echo "CONFIG_PACKAGE_hplip-ppds=y" >> .config
echo "CONFIG_PACKAGE_ghostscript=y" >> .config

echo "✅ diy-part2.sh 执行完成"
