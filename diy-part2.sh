#!/bin/bash

echo "=========================================="
echo "OpenWrt 24.10 Official Stable Build"
echo "diy-part2.sh - 更新feeds后的配置"
echo "=========================================="

# 1. 设置默认主机名
echo "[1/6] 设置默认主机名..."
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate 2>/dev/null || true
sed -i 's/OpenWrt/OpenWrt-24.10/g' package/base-files/files/bin/config_generate 2>/dev/null || true

# 2. 设置默认时区为上海
echo "[2/6] 设置默认时区..."
sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/'CST-8'/a \\\t\tset system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

# 3. 设置默认主题
echo "[3/6] 设置默认主题为Material..."
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' package/feeds/luci/luci/Makefile 2>/dev/null || true

# 4. 修复 glib2 编译问题（PassWall依赖）
# 错误: Malformed value in machine file variable 'c_ld': lexer [@ld@]
# 原因: meson 交叉编译模板缺少 @ld@ 占位符，或编译缓存残留
# 修复: 检查并补全 meson 模板 + 清理 glib2 缓存
echo "[4/5] 修复 glib2 meson 编译配置..."
MESON_CROSS=$(find staging_dir/host/lib/meson -name "openwrt-cross.txt.in" 2>/dev/null | head -1)
if [ -n "$MESON_CROSS" ]; then
    if ! grep -q '@ld@' "$MESON_CROSS" 2>/dev/null; then
        sed -i '/@nm@/a @ld@' "$MESON_CROSS" 2>/dev/null || true
        echo "  - 已添加 @ld@ 到 meson 交叉编译模板"
    else
        echo "  - meson 模板已包含 @ld@，无需修改"
    fi
else
    echo "  - meson 模板尚未生成（将在编译时自动处理）"
fi
# 清理 glib2 残留配置缓存（防止缓存冲突）
rm -rf build_dir/target-*/glib-*/.configured_* 2>/dev/null || true
rm -rf staging_dir/target-*/stamp/.glib2_* 2>/dev/null || true
echo "  - glib2 缓存已清理"

# 4. 添加自定义banner
echo "[4/6] 添加自定义banner..."
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

# 5. CUPS 汉化集成
echo "[5/6] 集成CUPS中文汉化..."
mkdir -p package/base-files/files/usr/share/cups/templates
mkdir -p package/base-files/files/usr/share/cups/doc-root

# 从仓库复制汉化文件（需要把CUPS_2.3.1_zh_CN.zip上传到仓库）
if [ -f "$GITHUB_WORKSPACE/CUPS_2.3.1_zh_CN.zip" ]; then
    unzip -o $GITHUB_WORKSPACE/CUPS_2.3.1_zh_CN.zip -d /tmp/cups-zh
    # 复制中文模板到 templates
    cp -r /tmp/cups-zh/zh_CN/* package/base-files/files/usr/share/cups/templates/
    # 复制首页
    cp /tmp/cups-zh/index.html package/base-files/files/usr/share/cups/doc-root/ 2>/dev/null || true
    chmod -R 755 package/base-files/files/usr/share/cups/templates
    chmod -R 755 package/base-files/files/usr/share/cups/doc-root
    rm -rf /tmp/cups-zh
    echo "CUPS汉化文件已集成"
else
    echo "警告: 未找到CUPS_2.3.1_zh_CN.zip，跳过"
fi

# 6. 设置GRUB等待时间为2秒
echo "[6/6] 设置GRUB等待时间..."
sed -i 's/set timeout=.*/set timeout=2/' package/base-files/files/boot/grub/grub.cfg 2>/dev/null || echo "set timeout=2" > package/base-files/files/boot/grub/grub.cfg

# 6. CUPS 默认配置（启用Avahi）
echo "[6/6] 配置CUPS默认设置..."
mkdir -p package/base-files/files/etc/cups

cat > package/base-files/files/etc/cups/cupsd.conf << 'EOF'
# CUPS 配置文件 - OpenWrt 24.10
# 启用网络打印和Avahi发现

# 监听地址
Listen *:631
Listen /var/run/cups/cups.sock

# 日志级别
LogLevel warn
AccessLog /var/log/cups/access_log
ErrorLog /var/log/cups/error_log

# 默认策略
DefaultPolicy default

# Web界面访问控制
<Location />
  Order allow,deny
  Allow @LOCAL
</Location>

# 管理界面
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

# 打印机共享
<Location /printers>
  Order allow,deny
  Allow @LOCAL
</Location>

# 启用Avahi/DNS-SD打印机发现
Browsing On
BrowseLocalProtocols dnssd
EOF

# Avahi 服务文件（让CUPS打印机被发现）
mkdir -p package/base-files/files/etc/avahi/services
cat > package/base-files/files/etc/avahi/services/cups.service << 'EOF'
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
EOF

echo "=========================================="
echo "构建信息:"
echo "  - OpenWrt版本: 24.10 Official Stable"
echo "  - 目标平台: x86_64"
echo "  - 打印: CUPS + Avahi + 中文界面"
echo "  - 网络: Tailscale/ACME/文件管理器/访问控制"
echo "=========================================="
