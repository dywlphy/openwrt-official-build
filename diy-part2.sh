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
echo "[1/5] 设置默认主机名..."
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate 2>/dev/null || true
sed -i 's/OpenWrt/OpenWrt-24.10/g' package/base-files/files/bin/config_generate 2>/dev/null || true

# 2. 设置默认时区为上海
echo "[2/5] 设置默认时区..."
sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/'CST-8'/a \\\t\tset system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

# 3. 设置默认主题为Material
echo "[3/5] 设置默认主题为Material..."
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' package/feeds/luci/luci/Makefile 2>/dev/null || true

# 4. 添加自定义banner
echo "[4/5] 添加自定义banner..."
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

# 5. 创建 cups-zh-cn 中文汉化包 + GRUB配置
echo "[5/5] 创建CUPS汉化包和GRUB配置..."

# 创建 cups-zh-cn 自定义包
mkdir -p package/cups-zh-cn/files/usr/share/cups/zh_CN
mkdir -p package/cups-zh-cn/files/usr/share/cups/doc-root

if [ -f "$GITHUB_WORKSPACE/CUPS_2.3.1_zh_CN.zip" ]; then
    unzip -o $GITHUB_WORKSPACE/CUPS_2.3.1_zh_CN.zip -d /tmp/cups-zh
    # 复制中文模板到包目录
    cp -r /tmp/cups-zh/zh_CN/* package/cups-zh-cn/files/usr/share/cups/zh_CN/ 2>/dev/null || true
    # 复制首页
    cp /tmp/cups-zh/index.html package/cups-zh-cn/files/usr/share/cups/doc-root/ 2>/dev/null || true
    rm -rf /tmp/cups-zh
    echo "  - CUPS中文模板已准备"
else
    echo "  - 警告: 未找到CUPS_2.3.1_zh_CN.zip"
fi

# 创建 cups-zh-cn Makefile
cat > package/cups-zh-cn/Makefile << 'MAKEEOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=cups-zh-cn
PKG_VERSION:=2.3.1
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
	$(INSTALL_DIR) $(1)/usr/share/cups/zh_CN
	$(CP) ./files/usr/share/cups/zh_CN/* $(1)/usr/share/cups/zh_CN/
	$(INSTALL_DIR) $(1)/usr/share/cups/doc-root
	$(INSTALL_BIN) ./files/usr/share/cups/doc-root/index.html $(1)/usr/share/cups/doc-root/
endef

define Package/cups-zh-cn/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	[ -d /usr/share/cups/zh_CN ] && {
		cp -rf /usr/share/cups/zh_CN/* /usr/share/cups/templates/
		rm -rf /usr/share/cups/zh_CN
		[ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd restart 2>/dev/null
	}
}
exit 0
endef

define Package/cups-zh-cn/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	[ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd restart 2>/dev/null
}
exit 0
endef

$(eval $(call BuildPackage,cups-zh-cn))
MAKEEOF

echo "  - cups-zh-cn 包已创建"

echo "=========================================="
echo "构建信息:"
echo "  - OpenWrt版本: 24.10 Official Stable"
echo "  - 目标平台: x86_64"
echo "  - 打印: CUPS + Avahi + 中文界面(cups-zh-cn)"
echo "  - VPN: WireGuard + pbr"
echo "  - 网络: Tailscale/ACME/frp"
echo "=========================================="
