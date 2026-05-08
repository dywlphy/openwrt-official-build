#!/bin/bash
# ==========================================
# diy-part2.sh - 自启动脚本 + 中文设置 + GRUB修复
# ==========================================

# 确保在 openwrt 目录
cd openwrt

echo "===== diy-part2.sh 开始 ====="

# ==========================================
# 1. 修复 GRUB 超时为 0 秒
# ==========================================
echo "===== 修复 GRUB 超时为 0 秒 ====="
GRUB_FIXED=0
for cfg in target/linux/x86/image/grub-efi.cfg target/linux/x86/image/grub-pc.cfg target/linux/x86/image/grub-iso.cfg; do
    if [ -f "$cfg" ]; then
        if grep -q "^set timeout=" "$cfg"; then
            sed -i 's/^set timeout=.*/set timeout=0/' "$cfg"
            echo "  已修改 $(basename $cfg): timeout=0"
            GRUB_FIXED=1
        fi
    fi
done
if [ $GRUB_FIXED -eq 0 ]; then
    echo "  警告: 未找到 GRUB 配置文件"
fi

# ==========================================
# 2. 创建自启动目录
# ==========================================
echo "===== 创建自启动目录 ====="
mkdir -p files/etc/init.d files/etc/rc.d files/etc/uci-defaults
echo "  目录创建完成"

# ==========================================
# 3. 服务自启动脚本
# ==========================================
echo "===== 创建服务自启动脚本 ====="
cat > files/etc/init.d/custom-autostart << 'EOF'
#!/bin/sh /etc/rc.common
START=99
start() {
    [ -x /etc/init.d/ksmbd ] && /etc/init.d/ksmbd enable && /etc/init.d/ksmbd start
    [ -x /etc/init.d/miniupnpd ] && /etc/init.d/miniupnpd enable && /etc/init.d/miniupnpd start
    [ -x /etc/init.d/ddns ] && /etc/init.d/ddns enable && /etc/init.d/ddns start
}
EOF
chmod +x files/etc/init.d/custom-autostart
ln -sf ../init.d/custom-autostart files/etc/rc.d/S99custom-autostart
echo "  自启动脚本创建完成"

# ==========================================
# 4. 自动共享脚本
# ==========================================
echo "===== 创建自动共享脚本 ====="
cat > files/etc/init.d/auto-share << 'AUTOEOF'
#!/bin/sh /etc/rc.common
START=95
start() {
    # 启用 SMB
    [ -x /etc/init.d/ksmbd ] && /etc/init.d/ksmbd enable
    # 配置 samba4
    uci set samba4=sambashare
    uci set samba4.enabled='1'
    uci add_list samba4.name='OpenWrt'
    uci set samba4.description='OpenWrt NAS'
    uci set samba4.browseable='yes'
    uci set samba4.read_only='no'
    uci set samba4.guest_ok='yes'
    uci commit samba4
    # 启用防火墙 samba 规则
    uci set firewall.allow_samba=rule
    uci set firewall.allow_samba.target='ACCEPT'
    uci set firewall.allow_samba.src='wan'
    uci set firewall.allow_samba.proto='tcp'
    uci set firewall.allow_samba.dest_port='445'
    uci commit firewall
}
AUTOEOF
chmod +x files/etc/init.d/auto-share
ln -sf ../init.d/auto-share files/etc/rc.d/S95auto-share
echo "  自动共享脚本创建完成"

# ==========================================
# 5. 设置默认语言为中文（关键！）
# ==========================================
echo "===== 设置默认语言为中文 ====="
cat > files/etc/uci-defaults/99-lang-zh-cn << 'UCI_EOF'
#!/bin/sh
uci set luci.main.lang='zh_cn'
uci commit luci
exit 0
UCI_EOF
chmod +x files/etc/uci-defaults/99-lang-zh-cn

# 验证文件是否创建成功
if [ -f "files/etc/uci-defaults/99-lang-zh-cn" ]; then
    echo "  中文设置脚本创建成功"
    cat files/etc/uci-defaults/99-lang-zh-cn
else
    echo "  错误: 中文设置脚本创建失败！"
    exit 1
fi

echo "===== diy-part2.sh 执行完成 ====="
