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
echo "[3/6] 设置默认主题为Material..."
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' package/feeds/luci/luci/Makefile 2>/dev/null || true

# 4. 创建 CUPS 中文汉化包
echo "[4/6] 创建 CUPS 中文汉化包..."

# 创建包目录
mkdir -p package/cups-zh-cn/files/usr/share/cups/templates
mkdir -p package/cups-zh-cn/files/usr/share/cups/doc-root

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
  unzip -o "$CUPS_ZIP" -d /tmp/cups-zh 2>/dev/null

  # zip 内结构: CUPS-zh/CUPS-2.4.2/usr_share_cups_templates/*.tmpl
  # zip 内结构: CUPS-zh/CUPS-2.4.2/usr_share_cups_doc-root/*
  TMPL_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_templates" 2>/dev/null | head -1)
  DOC_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_doc-root" 2>/dev/null | head -1)

  if [ -n "$TMPL_DIR" ]; then
    cp -r "$TMPL_DIR"/* package/cups-zh-cn/files/usr/share/cups/templates/ 2>/dev/null
    TMPL_COUNT=$(find package/cups-zh-cn/files/usr/share/cups/templates/ -type f 2>/dev/null | wc -l)
    echo "  - CUPS 中文模板已复制 ($TMPL_COUNT 个文件)"
  fi

  if [ -n "$DOC_DIR" ]; then
    cp -r "$DOC_DIR"/* package/cups-zh-cn/files/usr/share/cups/doc-root/ 2>/dev/null
    DOC_COUNT=$(find package/cups-zh-cn/files/usr/share/cups/doc-root/ -type f 2>/dev/null | wc -l)
    echo "  - CUPS 中文文档已复制 ($DOC_COUNT 个文件)"
  fi

  rm -rf /tmp/cups-zh
else
  echo "  - 警告: 未找到 CUPS-zh.zip，跳过汉化"
fi

# cups-zh-cn Makefile
cat > package/cups-zh-cn/Makefile << 'MAKEEOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=cups-zh-cn
PKG_VERSION:=2.4.2
PKG_RELEASE:=1

PKG_MAINTAINER:=OpenWrt Builder
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define Package/cups-zh-cn
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=CUPS Chinese (Simplified) Templates
  DEPENDS:=+cups
  PKGARCH:=all
endef

define Package/cups-zh-cn/description
  Simplified Chinese language templates for CUPS web interface.
  Replaces default English templates after installation.
endef

define Build/Compile
endef

define Package/cups-zh-cn/install
	$(INSTALL_DIR) $(1)/usr/share/cups/templates
	$(CP) ./files/usr/share/cups/templates/* $(1)/usr/share/cups/templates/
	$(INSTALL_DIR) $(1)/usr/share/cups/doc-root
	$(CP) ./files/usr/share/cups/doc-root/* $(1)/usr/share/cups/doc-root/
endef

$(eval $(call BuildPackage,cups-zh-cn))
MAKEEOF

echo "  - cups-zh-cn 包已创建"

# 5. 创建 uci-defaults 脚本（首次启动执行）
echo "[5/6] 创建 uci-defaults 脚本..."
mkdir -p package/base-files/files/etc/uci-defaults

# CUPS 汉化 + 配置
cat > package/base-files/files/etc/uci-defaults/98-cups-zh-cn << 'CUPSEOF'
#!/bin/sh
# 首次启动自动配置CUPS中文汉化和cupsd.conf

# 1. 替换CUPS中文模板（cups-zh-cn包已将文件安装到 /usr/share/cups/templates/）
#    这里确保模板文件权限正确
if [ -d /usr/share/cups/templates ]; then
    chmod 644 /usr/share/cups/templates/*.tmpl 2>/dev/null
    echo "CUPS中文模板就绪"
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

# 4. 重启服务
[ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon restart 2>/dev/null
[ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd restart 2>/dev/null

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

# 6. 添加自定义banner
echo "[6/6] 添加自定义banner..."
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
CUPS_TMPL=$(find package/cups-zh-cn/files/usr/share/cups/templates/ -type f 2>/dev/null | wc -l)
CUPS_DOC=$(find package/cups-zh-cn/files/usr/share/cups/doc-root/ -type f 2>/dev/null | wc -l)
echo "  - CUPS中文模板: $CUPS_TMPL 个"
echo "  - CUPS中文文档: $CUPS_DOC 个"
echo "  - CUPS uci-defaults: $(test -f package/base-files/files/etc/uci-defaults/98-cups-zh-cn && echo '存在' || echo '不存在')"
echo "  - GRUB uci-defaults: $(test -f package/base-files/files/etc/uci-defaults/99-grub-timeout && echo '存在' || echo '不存在')"

echo "=========================================="
echo "构建信息:"
echo "  - OpenWrt版本: 24.10 Official Stable"
echo "  - 目标平台: x86_64"
echo "  - 打印: CUPS + Avahi + 中文(cups-zh-cn)"
echo "  - NAT: Full Cone NAT (kmod-nft-fullcone)"
echo "  - VPN: WireGuard + pbr"
echo "  - 网络: Tailscale/ACME/frp"
echo "  - 控制: timecontrol"
echo "=========================================="
