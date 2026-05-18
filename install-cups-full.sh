#!/bin/bash
#
# Debian 全功能 CUPS 打印服务器安装脚本
# 包含：打印服务 + 所有驱动 + 扫描功能
#

set -e

echo "=========================================="
echo "Debian 全功能 CUPS 安装脚本"
echo "=========================================="

# ============================================
# 1. 安装 CUPS 核心组件
# ============================================
echo ""
echo "[1/6] 安装 CUPS 核心组件..."

apt-get install -y \
    cups \
    cups-bsd \
    cups-client \
    cups-filters \
    avahi-daemon \
    avahi-utils \
    ghostscript \
    poppler-utils \
    qpdf \
    unzip

# cups-pdf 在 Debian 13 已移除，尝试安装（Debian 12 可用）
apt-get install -y cups-pdf 2>/dev/null || echo "  提示: cups-pdf 在当前版本不可用（Debian 13 已移除）"

# ============================================
# 2. 安装打印机驱动
# ============================================
echo ""
echo "[2/6] 安装打印机驱动..."

# Brother 打印机驱动
apt-get install -y printer-driver-brlaser || echo "  警告: brlaser 安装失败"

# Samsung 打印机驱动
apt-get install -y printer-driver-splix || echo "  警告: splix 安装失败"

# Canon 网络打印（Debian 13 不可用）
apt-get install -y cups-bjnp 2>/dev/null || echo "  警告: cups-bjnp 安装失败（Debian 13 已移除）"

# gutenprint 通用驱动
apt-get install -y printer-driver-gutenprint || echo "  警告: gutenprint 安装失败"

# HP 打印机驱动
apt-get install -y hplip || echo "  警告: hplip 安装失败"

# 所有 打印机驱动
apt-get install -y printer-driver-all || echo "  警告: printer-driver-all 安装失败"

# Foomatic PPD 数据库
apt-get install -y foomatic-db-compressed-ppds || echo "  警告: foomatic 安装失败"

# ============================================
# 3. 配置 CUPS 网络访问
# ============================================
echo ""
echo "[3/6] 配置 CUPS 网络访问..."

# 备份原配置
cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.bak

# 修改监听地址
sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf

# 添加访问权限 - 根目录
sed -i '/<Location \/>/,/<\/Location>/{
    /Order allow,deny/a\  Allow all
}' /etc/cups/cupsd.conf

# 添加访问权限 - 管理页面
sed -i '/<Location \/admin>/,/<\/Location>/{
    /Order allow,deny/a\  Allow all
}' /etc/cups/cupsd.conf

# 添加访问权限 - 配置文件
sed -i '/<Location \/admin\/conf>/,/<\/Location>/{
    /Order allow,deny/a\  Allow all
}' /etc/cups/cupsd.conf

# 添加日志页面权限
if ! grep -q "<Location /admin/log>" /etc/cups/cupsd.conf; then
    cat >> /etc/cups/cupsd.conf << 'EOF'

<Location /admin/log>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow all
</Location>
EOF
fi

# 启用网络发现
sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf 2>/dev/null || true
sed -i 's/BrowseLocalProtocols none/BrowseLocalProtocols dnssd/' /etc/cups/cupsd.conf 2>/dev/null || true

# ============================================
# 3.1 汉化 CUPS Web 界面
# ============================================
echo ""
echo "[3.1/6] 汉化 CUPS Web 界面..."

# 安装中文语言包
apt-get install -y locales
sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen
locale-gen zh_CN.UTF-8

# 下载 CUPS 中文模板（优先使用本地文件）
CUPS_ZH_LOCAL="/root/CUPS-zh.zip"
if [ -f "$CUPS_ZH_LOCAL" ]; then
    echo "  使用本地 CUPS 中文模板: $CUPS_ZH_LOCAL"
    cp "$CUPS_ZH_LOCAL" /tmp/cups-zh.zip
else
    CUPS_ZH_URL="https://github.com/dywlphy/OpenWrt_24.10_CUPS_Avahi/raw/main/CUPS-zh.zip"
    echo "  下载 CUPS 中文模板..."
    wget -q -O /tmp/cups-zh.zip "$CUPS_ZH_URL" || {
        echo "  警告: 中文模板下载失败，使用备用方案"
        # 备用方案：直接修改首页导航栏
        if [ -f /usr/share/cups/doc-root/index.html ]; then
            sed -i 's|>Home<|>首页<|g; s|>Administration<|>管理<|g; s|>Classes<|>类<|g; s|>Jobs<|>任务<|g; s|>Printers<|>打印机<|g; s|>Help<|>帮助<|g' /usr/share/cups/doc-root/index.html
            echo "  - 首页导航栏已汉化"
        fi
    }
fi

# 解压并替换模板
if [ -f /tmp/cups-zh.zip ]; then
    unzip -o /tmp/cups-zh.zip -d /tmp/cups-zh
    
    # 查找模板目录
    TMPL_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_templates" | head -1)
    DOC_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_doc-root" | head -1)
    
    if [ -n "$TMPL_DIR" ]; then
        cp -r "$TMPL_DIR"/* /usr/share/cups/templates/
        chmod -R a+rX /usr/share/cups/templates/
        TMPL_COUNT=$(find /usr/share/cups/templates/ -name "*.tmpl" | wc -l)
        echo "  - CUPS 中文模板已安装 ($TMPL_COUNT 个文件)"
    fi
    
    if [ -n "$DOC_DIR" ]; then
        cp -r "$DOC_DIR"/* /usr/share/cups/doc-root/
        chmod -R a+rX /usr/share/cups/doc-root/
        echo "  - CUPS 中文文档已安装"
    fi
    
    rm -rf /tmp/cups-zh /tmp/cups-zh.zip
fi

# ============================================
# 4. 配置 Avahi 打印机发现
# ============================================
echo ""
echo "[4/6] 配置 Avahi 打印机发现..."

mkdir -p /etc/avahi/services
cat > /etc/avahi/services/cups.service << 'EOF'
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

# ============================================
# 5. 配置用户权限
# ============================================
echo ""
echo "[5/6] 配置用户权限..."

# 获取当前用户
CURRENT_USER=${SUDO_USER:-$(logname 2>/dev/null || echo "")}
if [ -z "$CURRENT_USER" ] || [ "$CURRENT_USER" = "root" ]; then
    # 如果没有普通用户，创建一个
    if ! id "cupsadmin" &>/dev/null; then
        useradd -m -s /bin/bash cupsadmin
        echo "请设置 cupsadmin 用户密码:"
        passwd cupsadmin
        CURRENT_USER="cupsadmin"
    fi
fi

# 将用户加入 lpadmin 组
usermod -a -G lpadmin "$CURRENT_USER"
echo "  - 用户 $CURRENT_USER 已加入 lpadmin 组"

# ============================================
# 6. 安装扫描功能
# ============================================
echo ""
echo "[6/6] 安装扫描功能..."

# 安装 SANE 扫描驱动（Debian 13 兼容）
apt-get install -y sane-utils 2>/dev/null || echo "  警告: sane-utils 安装失败"
apt-get install -y libsane 2>/dev/null || echo "  警告: libsane 安装失败（Debian 13 已移除）"
apt-get install -y sane-airscan 2>/dev/null || echo "  警告: sane-airscan 安装失败"
apt-get install -y ipp-usb 2>/dev/null || echo "  警告: ipp-usb 安装失败"

# 安装 scanservjs 依赖
apt-get install -y \
    imagemagick \
    tesseract-ocr \
    tesseract-ocr-chi-sim \
    nodejs \
    npm

# 下载并安装 scanservjs
SCAN_VERSION="v3.0.3"
echo "  下载 scanservjs $SCAN_VERSION..."
wget -q "https://github.com/sbs20/scanservjs/releases/download/${SCAN_VERSION}/scanservjs_3.0.3-1_all.deb" -O /tmp/scanservjs.deb || {
    echo "  警告: scanservjs 下载失败，跳过"
}
if [ -f /tmp/scanservjs.deb ]; then
    apt-get install -y /tmp/scanservjs.deb
    rm -f /tmp/scanservjs.deb
    echo "  - scanservjs 已安装"
fi

# ============================================
# 重启服务
# ============================================
echo ""
echo "重启服务..."
systemctl restart cups
systemctl restart avahi-daemon
systemctl enable cups
systemctl enable avahi-daemon

# scanservjs 服务 + 配置为 HTTP 模式（HTTPS 证书在 Debian 13 可能有兼容问题）
if command -v scanservjs &>/dev/null; then
    # 配置为 HTTP 模式
    SCAN_CONFIG_DIR="/usr/lib/scanservjs/config"
    mkdir -p "$SCAN_CONFIG_DIR"
    cat > "$SCAN_CONFIG_DIR/config.js" << 'SCANEOF'
module.exports = {
    config: {
        port: 8080,
        hostname: '0.0.0.0',
        https: false
    }
};
SCANEOF
    systemctl enable scanservjs 2>/dev/null || true
    systemctl restart scanservjs 2>/dev/null || true
fi

# ============================================
# 完成信息
# ============================================
echo ""
echo "=========================================="
echo "安装完成！"
echo "=========================================="
echo ""
# 获取 IP 地址
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "CUPS 管理页面: https://$IP_ADDR:631"
echo "scanservjs 扫描: http://$IP_ADDR:8080"
echo ""
echo "用户名: $CURRENT_USER"
echo "密码: 系统登录密码"
echo ""
echo "已安装的打印机驱动:"
echo "  - Brother (brlaser)"
echo "  - Samsung (splix)"
echo "  - 通用驱动 (gutenprint)"
echo "  - HP (hplip)"
echo "  - PDF 虚拟打印机 (cups-pdf, Debian 12)"
echo ""
echo "注意: cups-pdf 和 cups-bjnp 在 Debian 13 中不可用"
echo "=========================================="
