#!/bin/bash
#
# diy-part2.sh - 更新feeds后的自定义配置
# OpenWrt 24.10 版本
# 功能：CUPS后端汉化 + Web前端汉化 + 系统配置
#

echo "=========================================="
echo " OpenWrt 24.10 Official Stable Build"
echo " diy-part2.sh - 自定义配置"
echo "=========================================="

# ============================================
# 1. 设置默认主机名
# ============================================
echo ""
echo "[1/8] 设置默认主机名..."
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate 2>/dev/null || true
sed -i 's/OpenWrt/OpenWrt-24.10/g' package/base-files/files/bin/config_generate 2>/dev/null || true
grep -q "OpenWrt-24.10" package/base-files/files/bin/config_generate 2>/dev/null && echo " ✅ 主机名已设置为 OpenWrt-24.10" || echo " ❌ 主机名设置失败"

# ============================================
# 2. 设置默认时区为上海
# ============================================
echo ""
echo "[2/8] 设置默认时区..."
sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/'CST-8'/a \\\t\tset system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate
grep -q "CST-8" package/base-files/files/bin/config_generate 2>/dev/null && echo " ✅ 时区已设置为 Asia/Shanghai (CST-8)" || echo " ❌ 时区设置失败"

# ============================================
# 3. 设置默认主题为Material
# ============================================
echo ""
echo "[3/8] 设置默认主题为Material..."
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' package/feeds/luci/luci/Makefile 2>/dev/null || true
grep -q "luci-theme-material" feeds/luci/collections/luci/Makefile 2>/dev/null && echo " ✅ 默认主题已设置为 Material" || echo " ⚠️ 主题设置（将在编译时生效）"

# ============================================
# 3.1 修复 timecontrol 菜单路径
# ============================================
echo ""
echo "[3.1/8] 修复 timecontrol 菜单路径..."
TC_MENU=$(find package/feeds/timecontrol -name "luci-app-timecontrol.json" -path "*/menu.d/*" 2>/dev/null | head -1)
if [ -n "$TC_MENU" ]; then
  sed -i 's|"admin/control/|"admin/network/|g' "$TC_MENU"
  echo " ✅ timecontrol 菜单路径已修复: 网络 → Time Control"
else
  echo " ⚠️ 未找到 timecontrol 菜单配置文件（将由 uci-defaults 在首次启动修复）"
fi

# ============================================
# 3.2 修改 cups 编译配置以支持 NLS（后端汉化关键）
# ============================================
echo ""
echo "[3.2/8] 修改 cups 编译配置启用 NLS..."
CUPS_MAKEFILE=$(find feeds -name Makefile -path '*/cups/*' 2>/dev/null | grep -v "cups-bjnp\|cups-filters\|libcups" | head -1)
if [ -n "$CUPS_MAKEFILE" ]; then
    # 启用本地化支持
    if grep -q "\-\-disable-nls" "$CUPS_MAKEFILE"; then
        sed -i 's/--disable-nls/--enable-nls/' "$CUPS_MAKEFILE"
        echo " ✅ CUPS NLS 已启用"
    else
        echo " ⚠️ CUPS Makefile 中未找到 --disable-nls"
    fi
    
    # 增加对 libintl-full 的依赖
    if ! grep -q "libintl-full" "$CUPS_MAKEFILE"; then
        sed -i '/DEPENDS:=/s/$/ +libintl-full/' "$CUPS_MAKEFILE"
        echo " ✅ libintl-full 依赖已添加"
    else
        echo " ✅ libintl-full 依赖已存在"
    fi
else
    echo " ❌ 未找到 CUPS Makefile，NLS 未启用"
fi

# ============================================
# 4. 复制 CUPS 汉化资源到固件
# ============================================
echo ""
echo "[4/8] 复制 CUPS 汉化资源到固件..."

mkdir -p package/base-files/files/etc/cups-zh

# --- 4.1 复制 CUPS-zh.zip（前端模板） ---
CUPS_ZIP=""
for zip_name in "CUPS-zh.zip" "CUPS_2.3.1_zh_CN.zip" "cups-zh-cn.zip"; do
  if [ -f "$GITHUB_WORKSPACE/$zip_name" ]; then
    CUPS_ZIP="$GITHUB_WORKSPACE/$zip_name"
    break
  fi
done

if [ -n "$CUPS_ZIP" ]; then
  cp "$CUPS_ZIP" package/base-files/files/etc/cups-zh/CUPS-zh.zip
  echo " ✅ CUPS-zh.zip 已复制 ($(du -h package/base-files/files/etc/cups-zh/CUPS-zh.zip | cut -f1))"
else
  echo " ❌ 未找到 CUPS-zh.zip，前端汉化将跳过"
fi

# --- 4.2 复制 cups.mo（后端翻译） ---
CUPS_MO=""
for mo_name in "cups.mo" "cups_zh_CN.mo" "cups-zh_CN.mo"; do
  if [ -f "$GITHUB_WORKSPACE/$mo_name" ]; then
    CUPS_MO="$GITHUB_WORKSPACE/$mo_name"
    break
  fi
done

if [ -n "$CUPS_MO" ]; then
  cp "$CUPS_MO" package/base-files/files/etc/cups-zh/cups.mo
  echo " ✅ cups.mo 已复制 ($(du -h package/base-files/files/etc/cups-zh/cups.mo | cut -f1))"
else
  echo " ⚠️ 未找到 cups.mo，后端消息将保持英文"
fi

# ============================================
# 5. 创建 uci-defaults 脚本
# ============================================
echo ""
echo "[5/8] 创建 uci-defaults 脚本..."
mkdir -p package/base-files/files/etc/uci-defaults

# --- 96-opkg-mirror ---
cat > package/base-files/files/etc/uci-defaults/96-opkg-mirror << 'MIREOF'
#!/bin/sh
# 替换 opkg 源为清华镜像
if [ -f /etc/opkg/distfeeds.conf ]; then
    sed -i 's|downloads.openwrt.org|mirrors.tuna.tsinghua.edu.cn/openwrt|g' /etc/opkg/distfeeds.conf
    echo "opkg 已切换为清华镜像源"
fi
exit 0
MIREOF
chmod +x package/base-files/files/etc/uci-defaults/96-opkg-mirror
test -f package/base-files/files/etc/uci-defaults/96-opkg-mirror && echo " ✅ 96-opkg-mirror（清华镜像源）" || echo " ❌ 96-opkg-mirror 创建失败"

# --- 97-timecontrol-menu ---
cat > package/base-files/files/etc/uci-defaults/97-timecontrol-menu << 'TCEOF'
#!/bin/sh
# 修复 timecontrol 菜单路径
TC_MENU="/usr/share/luci/menu.d/luci-app-timecontrol.json"
if [ -f "$TC_MENU" ]; then
    sed -i 's|"admin/control/|"admin/network/|g' "$TC_MENU"
    echo "timecontrol 菜单路径已修复: 网络 → Time Control"
fi
rm -rf /tmp/luci-* 2>/dev/null
exit 0
TCEOF
chmod +x package/base-files/files/etc/uci-defaults/97-timecontrol-menu
test -f package/base-files/files/etc/uci-defaults/97-timecontrol-menu && echo " ✅ 97-timecontrol-menu（菜单路径修复）" || echo " ❌ 97-timecontrol-menu 创建失败"

# --- 98-cups-zh-cn（核心汉化脚本） ---
cat > package/base-files/files/etc/uci-defaults/98-cups-zh-cn << 'CUPSEOF'
#!/bin/sh
# 首次启动自动配置 CUPS 中文汉化和 cupsd.conf

echo "=========================================="
echo " CUPS 中文汉化脚本 (uci-defaults)"
echo "=========================================="

# ============================================
# 第一步：系统中文环境配置
# ============================================
echo ""
echo "[1/5] 配置系统中文环境..."

# 设置系统语言
uci set system.@system[0].language='zh_CN' 2>/dev/null || true
uci commit system 2>/dev/null || true

# 写入环境变量（确保重启后仍生效）
if ! grep -q "zh_CN.UTF-8" /etc/profile 2>/dev/null; then
    echo 'export LC_MESSAGES="zh_CN.UTF-8"' >> /etc/profile
    echo 'export LANG="zh_CN.UTF-8"' >> /etc/profile
fi
export LC_MESSAGES="zh_CN.UTF-8"
export LANG="zh_CN.UTF-8"

# 生成中文 locale
if command -v locale-gen >/dev/null 2>&1; then
    if ! grep -q "zh_CN.UTF-8" /etc/locale.gen 2>/dev/null; then
        echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
    fi
    locale-gen 2>/dev/null
    echo " ✅ locale 已生成"
else
    echo " ⚠️ locale-gen 不可用，跳过"
fi

# ============================================
# 第二步：部署 CUPS 中文翻译文件（后端汉化）
# ============================================
echo ""
echo "[2/5] 部署 CUPS 中文翻译文件..."

CUPS_MO="/etc/cups-zh/cups.mo"
if [ -f "$CUPS_MO" ]; then
    mkdir -p /usr/share/locale/zh_CN/LC_MESSAGES
    cp "$CUPS_MO" /usr/share/locale/zh_CN/LC_MESSAGES/cups.mo
    chmod 644 /usr/share/locale/zh_CN/LC_MESSAGES/cups.mo
    rm -f "$CUPS_MO"
    echo " ✅ CUPS 中文翻译文件已部署"
else
    echo " ⚠️ 未找到 cups.mo，后端消息将保持英文"
fi

# ============================================
# 第三步：部署前端汉化模板
# ============================================
echo ""
echo "[3/5] 部署 CUPS 前端汉化模板..."

CUPS_ZIP="/etc/cups-zh/CUPS-zh.zip"
if [ -f "$CUPS_ZIP" ] && command -v unzip >/dev/null 2>&1; then
    unzip -o "$CUPS_ZIP" -d /tmp/cups-zh >/dev/null 2>&1
    
    # 兼容两种 zip 内部路径结构
    TMPL_DIR=$(find /tmp/cups-zh -type d -name "templates" -path "*/cups/*" 2>/dev/null | head -1)
    DOC_DIR=$(find /tmp/cups-zh -type d -name "doc-root" -path "*/cups/*" 2>/dev/null | head -1)
    [ -z "$TMPL_DIR" ] && TMPL_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_templates" 2>/dev/null | head -1)
    [ -z "$DOC_DIR" ] && DOC_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_doc-root" 2>/dev/null | head -1)

    if [ -n "$TMPL_DIR" ] && [ -d "$TMPL_DIR" ]; then
        cp -rf "$TMPL_DIR"/* /usr/share/cups/templates/ 2>/dev/null
        chmod 644 /usr/share/cups/templates/*.tmpl 2>/dev/null
        TMPL_COUNT=$(find /usr/share/cups/templates/ -name "*.tmpl" 2>/dev/null | wc -l)
        echo " ✅ 中文模板已安装 ($TMPL_COUNT 个文件)"
    else
        echo " ⚠️ 未找到模板目录"
    fi

    if [ -n "$DOC_DIR" ] && [ -d "$DOC_DIR" ]; then
        mkdir -p /usr/share/cups/doc-root/
        cp -rf "$DOC_DIR"/* /usr/share/cups/doc-root/ 2>/dev/null
        chmod 644 /usr/share/cups/doc-root/*.html 2>/dev/null
        echo " ✅ 中文文档已安装"
    else
        echo " ⚠️ 未找到文档目录"
    fi

    chmod -R a+rX /usr/share/cups/templates/ /usr/share/cups/doc-root/ 2>/dev/null
    rm -rf /tmp/cups-zh 2>/dev/null
    rm -f "$CUPS_ZIP"
else
    echo " ⚠️ CUPS-zh.zip 或 unzip 不可用，使用 sed 备用方案"
fi

# ============================================
# 第四步：强制汉化首页（兜底方案）
# ============================================
echo ""
echo "[4/5] 强制汉化 CUPS 首页..."

if [ -f /usr/share/cups/doc-root/index.html ]; then
    # 导航栏汉化
    sed -i 's|>Home<|>首页<|g; s|>Administration<|>管理<|g; s|>Classes<|>类<|g; s|>Jobs<|>任务<|g; s|>Printers<|>打印机<|g; s|>Help<|>帮助<|g' /usr/share/cups/doc-root/index.html
    # 标题栏汉化
    sed -i 's|CUPS for Users|用户|g; s|CUPS for Administrators|管理员|g; s|CUPS for Developers|开发人员|g' /usr/share/cups/doc-root/index.html
    # 网页标题
    sed -i 's|<title>CUPS.*</title>|<title>CUPS 打印服务器</title>|g' /usr/share/cups/doc-root/index.html
    echo " ✅ CUPS 首页已强制汉化"
else
    echo " ⚠️ index.html 不存在，跳过首页汉化"
fi

# ============================================
# 第五步：配置 cupsd.conf + Avahi
# ============================================
echo ""
echo "[5/5] 配置 cupsd.conf 和 Avahi..."

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
echo " ✅ cupsd.conf 已配置"

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
echo " ✅ Avahi 服务已配置"

# 启用并重载服务
[ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon enable 2>/dev/null && /etc/init.d/avahi-daemon reload 2>/dev/null
[ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd enable 2>/dev/null && /etc/init.d/cupsd reload 2>/dev/null

# 将 root 加入 lpadmin 组
usermod -a -G lpadmin root 2>/dev/null

echo ""
echo "=========================================="
echo " CUPS 汉化配置完成"
echo "=========================================="
exit 0
CUPSEOF
chmod +x package/base-files/files/etc/uci-defaults/98-cups-zh-cn
test -f package/base-files/files/etc/uci-defaults/98-cups-zh-cn && echo " ✅ 98-cups-zh-cn（CUPS汉化+配置）" || echo " ❌ 98-cups-zh-cn 创建失败"

# --- 99-grub-timeout ---
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

# ============================================
# 6. 添加自定义banner
# ============================================
echo ""
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
test -f package/base-files/files/etc/banner && echo " ✅ 自定义banner已创建" || echo " ❌ banner创建失败"

# ============================================
# 7. 确保依赖包已选中
# ============================================
echo ""
echo "[7/8] 检查依赖包配置..."
if [ -f .config ]; then
    if ! grep -q "CONFIG_PACKAGE_libintl-full=y" .config; then
        echo "CONFIG_PACKAGE_libintl-full=y" >> .config
        echo " ✅ 已添加 libintl-full 到 .config"
    else
        echo " ✅ libintl-full 已存在"
    fi
    if ! grep -q "CONFIG_PACKAGE_musl-utils=y" .config; then
        echo "CONFIG_PACKAGE_musl-utils=y" >> .config
        echo " ✅ 已添加 musl-utils 到 .config"
    else
        echo " ✅ musl-utils 已存在"
    fi
else
    echo " ⚠️ .config 不存在，无法检查依赖"
fi

# ============================================
# 8. 触发 base-files 重新打包
# ============================================
echo ""
echo "[8/8] 触发 base-files 重新打包..."
touch package/base-files/Makefile
echo " ✅ base-files Makefile 时间戳已更新"

# ============================================
# 调试信息
# ============================================
echo ""
echo "=========================================="
echo " 调试信息"
echo "=========================================="
echo ""
test -f package/base-files/files/etc/cups-zh/CUPS-zh.zip && echo " ✅ CUPS-zh.zip ($(du -h package/base-files/files/etc/cups-zh/CUPS-zh.zip | cut -f1))" || echo " ❌ CUPS-zh.zip 未找到"
test -f package/base-files/files/etc/cups-zh/cups.mo && echo " ✅ cups.mo ($(du -h package/base-files/files/etc/cups-zh/cups.mo | cut -f1))" || echo " ⚠️ cups.mo 未找到（后端消息将保持英文）"
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