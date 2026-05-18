#!/bin/bash
#
# diy-part2.sh - 更新feeds后的自定义配置
# OpenWrt 24.10 版本
#

echo "=========================================="
echo "OpenWrt 24.10 Official Stable Build"
echo "diy-part2.sh - 自定义配置"
echo "=========================================="

# 1. 设置默认主机名
echo "[1/6] 设置默认主机名..."
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate 2>/dev/null || true
sed -i 's/OpenWrt/OpenWrt-24.10/g' package/base-files/files/bin/config_generate 2>/dev/null || true

# 2. 设置默认时区为上海
echo "[2/6] 设置默认时区..."
sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/'CST-8'/a \\\t\tset system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

# 3. 设置默认主题为Material
echo "[3/7] 设置默认主题为Material..."
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' package/feeds/luci/luci/Makefile 2>/dev/null || true

# 3.1 修复 timecontrol 菜单路径（24.10 没有 admin/control 父菜单）
echo "[3.1/8] 修复 timecontrol 菜单路径..."
TC_MENU=$(find package/feeds/timecontrol -name "luci-app-timecontrol.json" -path "*/menu.d/*" 2>/dev/null | head -1)
if [ -n "$TC_MENU" ]; then
  sed -i 's|"admin/control/|"admin/network/|g' "$TC_MENU"
  echo "  - 已修复: $TC_MENU"
  echo "  - 菜单位置: 网络 → Time Control"
else
  echo "  - 警告: 未找到 timecontrol 菜单配置文件"
fi

# 4. 复制 CUPS-zh.zip 到固件（首次启动时解压，确保不被 cups 覆盖）
echo "[4/8] 复制 CUPS 中文包到固件..."

# 查找 CUPS-zh.zip（仓库根目录，与 config.txt 同目录）
CUPS_ZIP=""
for zip_name in "CUPS-zh.zip" "CUPS_2.3.1_zh_CN.zip" "cups-zh-cn.zip"; do
  if [ -f "$GITHUB_WORKSPACE/$zip_name" ]; then
    CUPS_ZIP="$GITHUB_WORKSPACE/$zip_name"
    break
  fi
done

if [ -n "$CUPS_ZIP" ]; then
  echo "  找到 CUPS 中文包: $CUPS_ZIP"
  mkdir -p package/base-files/files/etc/cups-zh
  cp "$CUPS_ZIP" package/base-files/files/etc/cups-zh/CUPS-zh.zip
  echo "  - CUPS-zh.zip 已复制到固件（将在首次启动时解压）"
else
  echo "  - 警告: 未找到 CUPS-zh.zip，跳过汉化"
fi

# 5. 创建 uci-defaults 脚本（首次启动执行）
echo "[5/8] 创建 uci-defaults 脚本..."
mkdir -p package/base-files/files/etc/uci-defaults

# CUPS 汉化 + 配置
cat > package/base-files/files/etc/uci-defaults/98-cups-zh-cn << 'CUPSEOF'
#!/bin/sh
# 首次启动自动配置CUPS中文汉化和cupsd.conf

# 1. 解压 CUPS-zh.zip 覆盖英文模板（确保在 cups 安装完成后执行）
CUPS_ZIP="/etc/cups-zh/CUPS-zh.zip"
if [ -f "$CUPS_ZIP" ] && [ -x /usr/bin/unzip ]; then
    unzip -o "$CUPS_ZIP" -d /tmp/cups-zh >/dev/null 2>&1
    TMPL_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_templates" | head -1)
    DOC_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_doc-root" | head -1)

    if [ -n "$TMPL_DIR" ]; then
        cp -r "$TMPL_DIR"/* /usr/share/cups/templates/
        chmod 644 /usr/share/cups/templates/*.tmpl 2>/dev/null
        echo "CUPS中文模板已安装"
    fi

    if [ -n "$DOC_DIR" ]; then
        cp -r "$DOC_DIR"/* /usr/share/cups/doc-root/
        chmod 644 /usr/share/cups/doc-root/*.html 2>/dev/null
        echo "CUPS中文文档已安装"
    fi

    chmod -R a+rX /usr/share/cups/templates/ /usr/share/cups/doc-root/ 2>/dev/null
    rm -rf /tmp/cups-zh 2>/dev/null
    rm -f "$CUPS_ZIP"
    echo "CUPS汉化完成（zip已删除释放空间）"
else
    # 备用方案：直接用 sed 汉化首页导航栏
    if [ -f /usr/share/cups/doc-root/index.html ]; then
        sed -i 's|>Home<|>首页<|g; s|>Administration<|>管理<|g; s|>Classes<|>类<|g; s|>Jobs<|>任务<|g; s|>Printers<|>打印机<|g; s|>Help<|>帮助<|g' /usr/share/cups/doc-root/index.html
        sed -i 's|CUPS for Users|用户|g; s|CUPS for Administrators|管理员|g; s|CUPS for Developers|开发人员|g' /usr/share/cups/doc-root/index.html
        echo "CUPS首页已汉化（sed备用方案）"
    fi
fi

# 2. 配置cupsd.conf（局域网访问 + Avahi发现）
mkdir -p /etc/cups
cat > /etc/cups/cupsd.conf << 'CONF'
Listen *:631
Listen /var/run/cups/cups.sock
LogLevel warn
AccessLog /var/log/cups/access_log
ErrorLog /var/log/cups/error_log
DefaultPolicy default

<Location />
  Order allow,deny
  Allow @LOCAL
</Location>

<Location /admin>
  Order allow,deny
  Allow @LOCAL
</Location>

<Location /admin/conf>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow @LOCAL
</Location>

<Location /admin/log>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow @LOCAL
</Location>

<Location /printers>
  Order allow,deny
  Allow @LOCAL
</Location>

Browsing On
BrowseLocalProtocols dnssd
CONF

# 3. 配置Avahi服务（打印机发现）
mkdir -p /etc/avahi/services
cat > /etc/avahi/services/cups.service << 'AVAHI'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">CUPS 打印服务器 @ %h</name>
  <service>
    <type>_ipp._tcp</type>
    <port>631</port>
    <txt-record>txtvers=1</txt-record>
    <txt-record>qtotal=1</txt-record>
    <txt-record>rp=printers/</txt-record>
  </service>
</service-group>
AVAHI

# 4. 启用并重载服务（首次启动时其他init脚本可能未完成，用enable+reload更安全）
[ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon enable && /etc/init.d/avahi-daemon reload 2>/dev/null
[ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd enable && /etc/init.d/cupsd reload 2>/dev/null

# 5. 将默认用户加入 lpadmin 组（允许管理打印机）
usermod -a -G lpadmin root 2>/dev/null

echo "CUPS配置完成"
exit 0
CUPSEOF
chmod +x package/base-files/files/etc/uci-defaults/98-cups-zh-cn
echo "  - CUPS uci-defaults脚本已创建"

# GRUB 超时修改
cat > package/base-files/files/etc/uci-defaults/99-grub-timeout << 'GRUBEOF'
#!/bin/sh
# 首次启动自动将GRUB等待时间改为2秒
if [ -f /boot/grub/grub.cfg ]; then
    sed -i 's/^set timeout=.*/set timeout=2/' /boot/grub/grub.cfg
    echo "GRUB timeout 已设置为 2 秒"
fi
exit 0
GRUBEOF
chmod +x package/base-files/files/etc/uci-defaults/99-grub-timeout
echo "  - GRUB uci-defaults脚本已创建"

# opkg 换国内源（清华镜像）
cat > package/base-files/files/etc/uci-defaults/96-opkg-mirror << 'MIREOF'
#!/bin/sh
# 替换 opkg 源为清华镜像（国内访问更快）
if [ -f /etc/opkg/distfeeds.conf ]; then
    sed -i 's|downloads.openwrt.org|mirrors.tuna.tsinghua.edu.cn/openwrt|g' /etc/opkg/distfeeds.conf
    echo "opkg 已切换为清华镜像源"
fi
exit 0
MIREOF
chmod +x package/base-files/files/etc/uci-defaults/96-opkg-mirror
echo "  - opkg 国内源 uci-defaults脚本已创建"

# timecontrol 菜单路径修复（首次启动时执行，确保包安装后仍生效）
cat > package/base-files/files/etc/uci-defaults/97-timecontrol-menu << 'TCEOF'
#!/bin/sh
# 修复 timecontrol 菜单路径：admin/control → admin/network
# 原因：OpenWrt 24.10 没有 admin/control 父菜单，包安装后原始路径无效
TC_MENU="/usr/share/luci/menu.d/luci-app-timecontrol.json"
if [ -f "$TC_MENU" ]; then
    sed -i 's|"admin/control/|"admin/network/|g' "$TC_MENU"
    echo "timecontrol 菜单路径已修复: 网络 → Time Control"
fi
# 清除 LuCI 缓存使菜单生效
rm -rf /tmp/luci-* 2>/dev/null
exit 0
TCEOF
chmod +x package/base-files/files/etc/uci-defaults/97-timecontrol-menu
echo "  - timecontrol 菜单修复 uci-defaults脚本已创建"

# 6. 添加自定义banner
echo "[6/8] 添加自定义banner..."
cat > package/base-files/files/etc/banner << 'EOF'
  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__| W I R E L E S S   F R E E D O M
 -----------------------------------------------------
 OpenWrt 24.10 Official Stable Build
 -----------------------------------------------------
EOF

# 调试信息
echo ""
echo "  === 自定义包文件统计 ==="
CUPS_ZIP_SIZE=$(du -h package/base-files/files/etc/cups-zh/CUPS-zh.zip 2>/dev/null | cut -f1)
echo "  - CUPS中文包: ${CUPS_ZIP_SIZE:-未找到}"
echo "  - CUPS uci-defaults: $(test -f package/base-files/files/etc/uci-defaults/98-cups-zh-cn && echo '存在' || echo '不存在')"
echo "  - GRUB uci-defaults: $(test -f package/base-files/files/etc/uci-defaults/99-grub-timeout && echo '存在' || echo '不存在')"

echo "=========================================="
echo "构建信息:"
echo "  - OpenWrt版本: 24.10 Official Stable"
echo "  - 目标平台: x86_64"
echo "  - 打印: CUPS + Avahi + 中文(CUPS-zh.zip首次启动解压)"
echo "  - NAT: Full Cone NAT (kmod-nft-fullcone)"
echo "  - VPN: WireGuard + pbr"
echo "  - 网络: Tailscale/ACME/frp"
echo "  - 控制: timecontrol"
echo "=========================================="

# 7. 触发 base-files 重新打包（确保 files/ 下的新增文件生效）
#    只需 touch Makefile 让构建系统检测到变化，无需手动 clean/compile
echo ""
echo "[额外] 触发 base-files 重新打包..."
touch package/base-files/Makefile
echo "  - base-files Makefile 时间戳已更新"
