# PVE + Debian 最小化 + 全功能 CUPS 安装指南

## 一、PVE 创建虚拟机

### 推荐配置

| 配置项 | 推荐值 | 说明 |
|--------|--------|------|
| CPU | 1 核 | CUPS 不需要多核 |
| 内存 | 512MB - 1GB | CUPS 占用约 50-100MB |
| 硬盘 | 8GB | 足够系统 + 打印缓存 |
| 网络 | 桥接模式 | 局域网访问 |
| ISO | debian-12/13-amd64-netinst.iso | 约 400-600MB |

---

## 二、Debian 最小化安装

### 下载 ISO

官网：https://www.debian.org/distrib/netinst

| 版本 | 代号 | 状态 | 推荐 |
|------|------|------|------|
| Debian 12 | Bookworm | 稳定版 | ✅ 生产环境推荐 |
| Debian 13 | Trixie | 测试版 | ⚠️ 可用，可能有不稳定风险 |

选择：`amd64` → `debian-12.x.x-amd64-netinst.iso` 或 `debian-13.x.x-amd64-netinst.iso`

### 安装步骤

1. **语言选择**：English（避免中文乱码）

2. **安装模式**：选择 **Install**（文本模式，非图形界面）

3. **分区**：
   - 选择 **Guided - use entire disk**
   - 选择 **All files in one partition**
   - 选择 **Finish partitioning and write changes to disk**

4. **软件选择**：**取消所有选项**，只保留：
   ```
   [ ] Debian desktop environment
   [ ] ... GNOME / KDE / Xfce ...
   [ ] web server
   [ ] print server          ← 取消！我们自己装
   [x] SSH server            ← 保留（远程管理）
   [ ] standard system utilities  ← 可取消
   ```

5. **完成安装**，重启

---

## 三、安装后配置

### 3.1 SSH 登录

```bash
ssh root@Debian_IP
# 密码：安装时设置的 root 密码
```

### 3.2 换国内源脚本

创建脚本：

```bash
cat > /root/change-source.sh << 'SCRIPT'
#!/bin/bash
#
# Debian 换国内源脚本
# 支持 Debian 11/12/13
#

set -e

# 检测 Debian 版本
DEBIAN_VER=$(cat /etc/debian_version | cut -d. -f1)
case "$DEBIAN_VER" in
    13)
        CODENAME="trixie"
        ;;
    12)
        CODENAME="bookworm"
        ;;
    11)
        CODENAME="bullseye"
        ;;
    *)
        echo "警告: 未识别的 Debian 版本，使用 bookworm"
        CODENAME="bookworm"
        ;;
esac

echo "检测到 Debian $DEBIAN_VER ($CODENAME)"

# 备份原 sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# 写入阿里云源
# 注意：Debian 13 (trixie) 没有单独的 security 源
if [ "$CODENAME" = "trixie" ]; then
    cat > /etc/apt/sources.list << EOF
# 阿里云镜像源 - Debian 13 (Trixie)
deb http://mirrors.aliyun.com/debian/ $CODENAME main contrib non-free non-free-firmware
deb http://mirrors.aliyun.com/debian/ $CODENAME-updates main contrib non-free non-free-firmware

# 清华镜像源（备用）
# deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $CODENAME main contrib non-free non-free-firmware
# deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $CODENAME-updates main contrib non-free non-free-firmware
EOF
else
    cat > /etc/apt/sources.list << EOF
# 阿里云镜像源 - Debian 12/11
deb http://mirrors.aliyun.com/debian/ $CODENAME main contrib non-free non-free-firmware
deb http://mirrors.aliyun.com/debian/ $CODENAME-updates main contrib non-free non-free-firmware
deb http://mirrors.aliyun.com/debian/ $CODENAME-backports main contrib non-free non-free-firmware
deb http://mirrors.aliyun.com/debian-security $CODENAME-security main contrib non-free non-free-firmware

# 清华镜像源（备用）
# deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $CODENAME main contrib non-free non-free-firmware
# deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $CODENAME-updates main contrib non-free non-free-firmware
# deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $CODENAME-backports main contrib non-free non-free-firmware
# deb https://mirrors.tuna.tsinghua.edu.cn/debian-security $CODENAME-security main contrib non-free non-free-firmware
EOF
fi

echo "已更换为阿里云镜像源"

# 更新软件包列表
echo "更新软件包列表..."
apt-get update

# 升级已安装的软件包
echo "升级软件包..."
apt-get upgrade -y

# 清理不需要的软件包
apt-get autoremove -y
apt-get clean

echo "=== 换源完成 ==="
SCRIPT

chmod +x /root/change-source.sh
./root/change-source.sh
```

### 3.3 移除不必要的服务

```bash
# 移除不需要的服务
apt-get purge -y \
    bluetooth \
    exim4* \
    nfs-common \
    rpcbind \
    tasksel \
    aptitude \
    doc-debian 2>/dev/null || true

# 清理
apt-get autoremove -y
apt-get clean

# 查看内存占用
free -h
```

---

## 四、安装全功能 CUPS

### 4.1 安装脚本

```bash
cat > /root/install-cups-full.sh << 'SCRIPT'
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
    cups-pdf \
    cups-filters \
    avahi-daemon \
    avahi-utils \
    ghostscript \
    poppler-utils \
    qpdf

# ============================================
# 2. 安装打印机驱动
# ============================================
echo ""
echo "[2/6] 安装打印机驱动..."

# Brother 打印机驱动
apt-get install -y printer-driver-brlaser || echo "  警告: brlaser 安装失败"

# Samsung 打印机驱动
apt-get install -y printer-driver-splix || echo "  警告: splix 安装失败"

# Canon 网络打印
apt-get install -y cups-bjnp || echo "  警告: cups-bjnp 安装失败"

# gutenprint 通用驱动
apt-get install -y printer-driver-gutenprint || echo "  警告: gutenprint 安装失败"

# HP 打印机驱动
apt-get install -y hplip || echo "  警告: hplip 安装失败"

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

# 下载 CUPS 中文模板
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

# 解压并替换模板
if [ -f /tmp/cups-zh.zip ]; then
    unzip -o /tmp/cups-zh.zip -d /tmp/cups-zh
    
    # 查找模板目录
    TMPL_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_templates" | head -1)
    DOC_DIR=$(find /tmp/cups-zh -type d -name "usr_share_cups_doc-root" | head -1)
    
    if [ -n "$TMPL_DIR" ]; then
        cp -r "$TMPL_DIR"/* /usr/share/cups/templates/
        TMPL_COUNT=$(find /usr/share/cups/templates/ -name "*.tmpl" | wc -l)
        echo "  - CUPS 中文模板已安装 ($TMPL_COUNT 个文件)"
    fi
    
    if [ -n "$DOC_DIR" ]; then
        cp -r "$DOC_DIR"/* /usr/share/cups/doc-root/
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

# 安装 SANE 扫描驱动
apt-get install -y \
    sane-utils \
    libsane \
    sane-airscan \
    ipp-usb

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

# scanservjs 服务
if command -v scanservjs &>/dev/null; then
    systemctl enable scanservjs 2>/dev/null || true
    systemctl start scanservjs 2>/dev/null || true
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
echo "  - Canon 网络打印 (cups-bjnp)"
echo "  - 通用驱动 (gutenprint)"
echo "  - HP (hplip)"
echo "  - PDF 虚拟打印机 (cups-pdf)"
echo ""
echo "PDF 打印输出目录: /var/spool/cups-pdf/$CURRENT_USER/"
echo "=========================================="
SCRIPT

chmod +x /root/install-cups-full.sh
```

### 4.2 执行安装

```bash
./root/install-cups-full.sh
```

---

## 五、安装后验证

### 5.1 检查服务状态

```bash
# 查看 CUPS 状态
systemctl status cups

# 查看 Avahi 状态
systemctl status avahi-daemon

# 查看 scanservjs 状态
systemctl status scanservjs
```

### 5.2 检查内存占用

```bash
free -h
```

预期结果：总占用约 **80-120MB**

### 5.3 访问测试

| 服务 | 地址 |
|------|------|
| CUPS 管理 | `https://Debian_IP:631` |
| scanservjs 扫描 | `http://Debian_IP:8080` |

---

## 六、资源占用对比

| 系统 | 内存占用 | 硬盘占用 |
|------|----------|----------|
| Debian 最小化 + CUPS | ~80MB | ~1.5GB |
| Debian 桌面版 + CUPS | ~400MB+ | ~8GB+ |
| OpenWrt + CUPS | ~40MB | ~200MB |

---

## 七、常见问题

### Q1: CUPS 管理页面无法访问

```bash
# 检查防火墙
iptables -L

# 开放端口
iptables -I INPUT -p tcp --dport 631 -j ACCEPT
iptables -I INPUT -p udp --dport 5353 -j ACCEPT
```

### Q2: 打印机无法被发现

```bash
# 重启 Avahi
systemctl restart avahi-daemon

# 检查 USB 打印机
lsusb
```

### Q3: scanservjs 无法启动

```bash
# 检查 Node.js 版本
node --version

# 手动启动
systemctl start scanservjs
```

---

## 八、一键安装命令汇总

```bash
# 1. 换国内源
./root/change-source.sh

# 2. 安装全功能 CUPS
./root/install-cups-full.sh
```
