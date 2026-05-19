#!/bin/bash
#
# diy-part2.sh - 更新feeds后的自定义配置
# OpenWrt 24.10 版本
#

echo "=========================================="
echo " OpenWrt 24.10 Official Stable Build"
echo " diy-part2.sh - 自定义配置"
echo "=========================================="

# 1. 设置默认主机名
echo ""
echo "[1/7] 设置默认主机名..."
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate 2>/dev/null || true
sed -i 's/OpenWrt/OpenWrt-24.10/g' package/base-files/files/bin/config_generate 2>/dev/null || true
grep -q "OpenWrt-24.10" package/base-files/files/bin/config_generate 2>/dev/null && echo " ✅ 主机名已设置为 OpenWrt-24.10" || echo " ❌ 主机名设置失败"

# 2. 设置默认时区为上海
echo ""
echo "[2/7] 设置默认时区..."
sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/'CST-8'/a \\\t\tset system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate
grep -q "CST-8" package/base-files/files/bin/config_generate 2>/dev/null && echo " ✅ 时区已设置为 Asia/Shanghai (CST-8)" || echo " ❌ 时区设置失败"

# 3. 设置默认主题为Material
echo ""
echo "[3/7] 设置默认主题为Material..."
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' package/feeds/luci/luci/Makefile 2>/dev/null || true
grep -q "luci-theme-material" feeds/luci/collections/luci/Makefile 2>/dev/null && echo " ✅ 默认主题已设置为 Material" || echo " ⚠️ 主题设置（将在编译时生效）"

# 3.1 修复 timecontrol 菜单路径（24.10 没有 admin/control 父菜单）
echo ""
echo "[3.1] 修复 timecontrol 菜单路径..."
TC_MENU=$(find package/feeds/timecontrol -name "luci-app-timecontrol.json" -path "*/menu.d/*" 2>/dev/null | head -1)
if [ -n "$TC_MENU" ]; then
  sed -i 's|"admin/control/|"admin/network/|g' "$TC_MENU"
  echo " ✅ timecontrol 菜单路径已修复: 网络 → Time Control"
else
  echo " ⚠️ 未找到 timecontrol 菜单配置文件（将由 uci-defaults 在首次启动修复）"
fi

# 4. 复制 CUPS-zh.zip 到固件（首次启动时解压，确保不被 cups 覆盖）
echo ""
echo "[4/7] 复制 CUPS 中文包到固件..."

CUPS_ZIP=""
for zip_name in "CUPS-zh.zip" "CUPS_2.3.1_zh_CN.zip" "cups-zh-cn.zip"; do
  if [ -f "$GITHUB_WORKSPACE/$zip_name" ]; then
    CUPS_ZIP="$GITHUB_WORKSPACE/$zip_name"
    break
  fi
done

if [ -n "$CUPS_ZIP" ]; then
  mkdir -p package/base-files/files/etc/cups-zh
  cp "$CUPS_ZIP" package/base-files/files/etc/cups-zh/CUPS-zh.zip
  echo " ✅ CUPS-zh.zip 已复制 ($(du -h package/base-files/files/etc/cups-zh/CUPS-zh.zip | cut -f1))"
else
  echo " ❌ 未找到 CUPS-zh.zip，汉化将跳过"
fi

# 复制 CUPS 中文翻译文件（cups.mo）用于汉化 cupsd 内置首页
CUPS_MO=""
for mo_name in "cups.mo"; do
  if [ -f "$GITHUB_WORKSPACE/$mo_name" ]; then
    CUPS_MO="$GITHUB_WORKSPACE/$mo_name"
    break
  fi
done

if [ -n "$CUPS_MO" ]; then
  mkdir -p package/base-files/files/etc/cups-zh
  cp "$CUPS_MO" package/base-files/files/etc/cups-zh/cups.mo
  echo " ✅ cups.mo 已复制 ($(du -h package/base-files/files/etc/cups-zh/cups.mo | cut -f1))"
else
  echo " ⚠️ 未找到 cups.mo，cupsd内置首页将保持英文"
fi

# 5. 创建 uci-defaults 脚本（首次启动执行）
echo ""
echo "[5/7] 创建 uci-defaults 脚本..."
mkdir -p package/base-files/files/etc/uci-defaults

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
test -f package/base-files/files/etc/uci-defaults/96-opkg-mirror && echo " ✅ 96-opkg-mirror（清华镜像源）" || echo " ❌ 96-opkg-mirror 创建失败"

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
test -f package/base-files/files/etc/uci-defaults/97-timecontrol-menu && echo " ✅ 97-timecontrol-menu（菜单路径修复）" || echo " ❌ 97-timecontrol-menu 创建失败"

# CUPS 汉化 + 配置
cat > package/base-files/files/etc/uci-defaults/98-cups-zh-cn << 'CUPSEOF'
#!/bin/sh
# 首次启动自动配置CUPS中文汉化和cupsd.conf

# 1. 解压 CUPS-zh.zip 覆盖英文模板（确保在 cups 安装完成后执行）
CUPS_ZIP="/etc/cups-zh/CUPS-zh.zip"
if [ -f "$CUPS_ZIP" ] && [ -x /usr/bin/unzip ]; then
    unzip -o "$CUPS_ZIP" -d /tmp/cups-zh >/dev/null 2>&1
    # 兼容两种zip内部路径结构: usr/share/cups/ 或 usr_share_cups_
    TMPL_DIR=$(find /tmp/cups-zh -type d -name "templates" -path "*/cups/*" | head -1)
    DOC_DIR=$(find /tmp/cups-zh -type d -name "doc-root" -path "*/cups/*" | head -1)
    [ -z "$TMPL_DIR" ] && TMPL_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_templates" | head -1)
    [ -z "$DOC_DIR" ] && DOC_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_doc-root" | head -1)

    if [ -n "$TMPL_DIR" ]; then
        cp -r "$TMPL_DIR"/* /usr/share/cups/templates/
        chmod 644 /usr/share/cups/templates/*.tmpl 2>/dev/null
        echo "CUPS中文模板已安装"
    fi

    if [ -n "$DOC_DIR" ]; then
        mkdir -p /usr/share/cups/doc-root/
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

# 2. 安装 CUPS 中文翻译文件（cups.mo）用于汉化 cupsd 内置首页
CUPS_MO="/etc/cups-zh/cups.mo"
if [ -f "$CUPS_MO" ]; then
    mkdir -p /usr/share/locale/zh_CN/LC_MESSAGES
    cp "$CUPS_MO" /usr/share/locale/zh_CN/LC_MESSAGES/cups.mo
    chmod 644 /usr/share/locale/zh_CN/LC_MESSAGES/cups.mo
    rm -f "$CUPS_MO"
    echo "CUPS中文翻译文件已安装"
fi

# 3. 配置cupsd.conf（局域网访问 + Avahi发现 + 中文语言）
mkdir -p /etc/cups
cat > /etc/cups/cupsd.conf << 'CONF'
Listen *:631
Listen /var/run/cups/cups.sock
LogLevel warn
AccessLog /var/log/cups/access_log
ErrorLog /var/log/cups/error_log
DefaultPolicy default
DefaultLanguage zh_CN

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

# 4. 配置Avahi服务（打印机发现）
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

# 5. 启用并重载服务（首次启动时其他init脚本可能未完成，用enable+reload更安全）
[ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon enable && /etc/init.d/avahi-daemon reload 2>/dev/null
[ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd enable && /etc/init.d/cupsd reload 2>/dev/null

# 6. 将默认用户加入 lpadmin 组（允许管理打印机）
usermod -a -G lpadmin root 2>/dev/null

echo "CUPS配置完成"
exit 0
CUPSEOF
chmod +x package/base-files/files/etc/uci-defaults/98-cups-zh-cn
test -f package/base-files/files/etc/uci-defaults/98-cups-zh-cn && echo " ✅ 98-cups-zh-cn（CUPS汉化+配置）" || echo " ❌ 98-cups-zh-cn 创建失败"

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
test -f package/base-files/files/etc/uci-defaults/99-grub-timeout && echo " ✅ 99-grub-timeout（GRUB 2秒启动）" || echo " ❌ 99-grub-timeout 创建失败"

# 6. 添加自定义banner
echo ""
echo "[6/7] 添加自定义banner..."
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
test -f package/base-files/files/etc/banner && echo " ✅ 自定义banner已创建" || echo " ❌ banner创建失败"

# 调试信息 - 根据实际检查结果显示 ✅/❌
echo ""
echo "=========================================="
echo " 调试信息"
echo "=========================================="
echo ""
test -f package/base-files/files/etc/cups-zh/CUPS-zh.zip && echo " ✅ CUPS-zh.zip ($(du -h package/base-files/files/etc/cups-zh/CUPS-zh.zip | cut -f1))" || echo " ❌ CUPS-zh.zip 未找到"
test -f package/base-files/files/etc/uci-defaults/96-opkg-mirror && echo " ✅ 96-opkg-mirror" || echo " ❌ 96-opkg-mirror 未创建"
test -f package/base-files/files/etc/uci-defaults/97-timecontrol-menu && echo " ✅ 97-timecontrol-menu" || echo " ❌ 97-timecontrol-menu 未创建"
test -f package/base-files/files/etc/uci-defaults/98-cups-zh-cn && echo " ✅ 98-cups-zh-cn" || echo " ❌ 98-cups-zh-cn 未创建"
test -f package/base-files/files/etc/uci-defaults/99-grub-timeout && echo " ✅ 99-grub-timeout" || echo " ❌ 99-grub-timeout 未创建"

echo ""
echo "=========================================="
echo " OpenWrt 24.10 Build Summary"
echo "=========================================="
echo ""
echo " ✅ LuCI 中文界面"
echo " ✅ CUPS 打印系统 + AirPrint 支持"
echo " ✅ ksmbd 文件共享"
echo " ✅ Full Cone NAT (nft-fullcone)"
echo " ✅ WireGuard VPN + pbr 策略路由"
echo " ✅ Tailscale / ACME / frp 内网穿透"
echo " ✅ 上网时间控制 (timecontrol)"
echo " ✅ 广告屏蔽 (adblock)"
echo " ✅ 网络工具 (UPnP, DDNS, WoL, SQM)"
echo " ✅ 网络流量统计 (nlbwmon)"
echo " ✅ Web 命令执行 (commands)"
echo " ✅ 断网自动重启 (watchcat)"
echo " ✅ HTTPS DNS Proxy (DoH/DoT)"
echo " ✅ 文件管理器 (filemanager)"
echo " ✅ 终端 (ttyd)"
echo ""
echo "=========================================="

# 7. 触发 base-files 重新打包
echo ""
echo "[7/7] 触发 base-files 重新打包..."
touch package/base-files/Makefile
echo " ✅ base-files Makefile 时间戳已更新"
