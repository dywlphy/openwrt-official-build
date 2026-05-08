#!/bin/bash
# ==========================================
# diy-part2.sh - 自启动脚本 + 自动共享 + CUPS + GRUB修复
# ==========================================

echo "===== 修复 GRUB 超时 ====="
for cfg in target/linux/x86/image/grub-efi.cfg target/linux/x86/image/grub-pc.cfg target/linux/x86/image/grub-iso.cfg; do
    if [ -f "$cfg" ]; then
        sed -i 's/^set timeout=.*/set timeout=0/' "$cfg"
        echo "  ✅ $(basename $cfg): timeout=0"
    fi
done

mkdir -p files/etc/init.d files/etc/rc.d

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

echo "===== 安装额外包 ====="

echo "从 smpackage 源安装 CUPS 核心包..."
./scripts/feeds install -f -p smpackage cups cups-filters dbus luci-app-cupsd 2>/dev/null && echo "  ✅ CUPS核心" || echo "  ⚠️ CUPS核心"

echo "从 immortalwrt 源安装扩展包..."
./scripts/feeds install -f -p immortalwrt cups-bjnp 2>/dev/null && echo "  ✅ cups-bjnp" || echo "  ⚠️ cups-bjnp"

echo "从官方源安装 avahi..."
./scripts/feeds install avahi-dbus-daemon 2>/dev/null && echo "  ✅ avahi-dbus-daemon" || {
    ./scripts/feeds install avahi-nodbus-daemon 2>/dev/null && echo "  ✅ avahi-nodbus-daemon" || echo "  ⚠️ avahi"
}

echo "✅ diy-part2.sh 执行完成"
