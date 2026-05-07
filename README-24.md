# OpenWrt 官方 24.10 编译

基于 OpenWrt 24.10 稳定版的 x86_64 固件编译配置，集成 CUPS 打印服务、SSR-Plus、ksmbd 文件共享等功能。

## 一、功能清单

### 基础系统
| 功能 | 状态 |
|------|------|
| x86_64 架构 | ✅ |
| EFI 启动 | ✅ |
| squashfs 文件系统 | ✅ |
| GRUB 超时 0 秒 | ✅ |
| rootfs 512MB | ✅ |
| 中文语言包 | ✅ |

### LuCI 界面
| 功能 | 状态 |
|------|------|
| luci-ssl（HTTPS） | ✅ |
| luci-theme-bootstrap | ✅ |
| 完整核心依赖 | ✅ |

### CUPS 打印系统
| 功能 | 状态 |
|------|------|
| cups 核心 | ✅ |
| cups-filters | ✅ |
| cups-bjnp（Canon 网络） | ✅ |
| luci-app-cupsd | ✅ |
| avahi-dbus-daemon | ✅ |
| ghostscript | ⚠️ 可选 |
| gutenprint | ⚠️ 可选 |
| foomatic-db | ⚠️ 可选 |

### 文件共享
| 功能 | 状态 |
|------|------|
| ksmbd-server | ✅ |
| luci-app-ksmbd | ✅ |
| 自动共享脚本 | ✅ |

### 科学上网
| 功能 | 状态 |
|------|------|
| luci-app-ssr-plus | ✅ |
| xray-core | ✅ |
| MosDNS | ❌ 禁用（Go 不兼容） |

### 网络功能
| 功能 | 状态 |
|------|------|
| WireGuard + LuCI | ✅ |
| UPnP | ✅ |
| DDNS | ✅ |
| SQM QoS | ✅ |
| 网络唤醒（WOL） | ✅ |
| nft-qos | ✅ |

### 实用工具
| 功能 | 状态 |
|------|------|
| curl | ✅ |
| bash | ✅ |
| vlmcsd + LuCI（KMS） | ✅ |
| htop | ✅ |
| iperf3 | ✅ |
| cfdisk | ✅ |
| e2fsprogs | ✅ |

### 系统维护
| 功能 | 状态 |
|------|------|
| luci-app-autoreboot | ✅ |
| luci-app-watchcat | ✅ |
| luci-app-commands | ✅ |
| luci-app-statistics | ✅ |
| luci-app-nlbwmon | ✅ |
| luci-app-adblock | ✅ |

### 磁盘与打印
| 功能 | 状态 |
|------|------|
| luci-app-diskman | ✅ |
| luci-app-usb-printer | ✅ |
| block-mount | ✅ |
| USB 内核模块 | ✅ |
| 文件系统（ext4, ntfs） | ✅ |

---

## 二、文件说明

| 文件 | 作用 |
|------|------|
| `.github/workflows/build-official.yml` | GitHub Actions 编译流程 |
| `config.txt` | 包选择配置 |
| `diy-part1.sh` | 添加第三方 feeds 源 |
| `diy-part2.sh` | GRUB 修复、自启动脚本、CUPS 包安装 |

---

## 三、编译方法

1. Fork 本仓库
2. 进入 **Actions** → **Build Official OpenWrt** → **Run workflow**
3. 等待编译完成（约 1-3 小时）
4. 下载固件：**Releases** 或 **Artifacts**

---

## 四、踩坑记录

### 坑 1：LuCI 界面报错 "Unhandled exception"
- **现象**：访问 LuCI 报错 `left-hand side expression is null`
- **原因**：缺少 `luci-base`、`rpcd-mod-*`、`ucode-mod-*` 等核心依赖
- **解决**：在 `build-official.yml` 的 **Force enable key packages** 步骤中强制启用完整依赖链

### 坑 2：GRUB 超时 5 秒
- **现象**：启动时等待 5 秒
- **原因**：`CONFIG_GRUB_TIMEOUT` 未生效，且源码模板默认 5 秒
- **解决**：
  1. `config.txt` 设置 `CONFIG_GRUB_TIMEOUT=0`
  2. `diy-part2.sh` 修改 `grub-efi.cfg` 中 `set timeout=0`

### 坑 3：CUPS 包被 defconfig 丢弃
- **现象**：`config.txt` 写的包在 `make defconfig` 后变成 `# ... is not set`
- **原因**：依赖不满足，自动禁用
- **解决**：添加 openwrt-cups 源，并在 **Force enable key packages** 中强制启用

### 坑 4：mosdns Go 版本不兼容
- **现象**：编译失败 `go >= 1.25.0 required`
- **原因**：OpenWrt 24.10 的 Go 版本较低
- **解决**：禁用 mosdns 和相关选项

### 坑 5：固件打包失败
- **现象**：`target/linux failed to build`
- **原因**：rootfs 太小，CUPS 全家桶放不下
- **解决**：`CONFIG_TARGET_ROOTFS_PARTSIZE=512`

### 坑 6：包名不一致
- **现象**：配置不生效
- **原因**：OpenWrt 包名与预期不同
- **解决**：
  - `libfreetype` → `freetype`
  - `libusb-1.0` → `libusb-1_0`
  - `libexpat` → `expat`
  - `avahi-daemon` → `avahi-dbus-daemon`

---

## 五、Feeds 源

| 源 | 用途 |
|------|------|
| 官方 packages | 基础包 |
| 官方 luci | LuCI 界面 |
| kenzok8/openwrt-packages | 实用工具包 |
| kenzok8/small | SSR-Plus 等科学上网 |
| kenzok8/small-package | CUPS 核心包 |
| fw876/helloworld | SSR-Plus 源码 |
| immortalwrt/packages | CUPS 扩展包 |
| op4packages/openwrt-cups | ghostscript, gutenprint, foomatic |

---

## 六、致谢

- [OpenWrt](https://openwrt.org/) 官方团队
- [SSR-Plus](https://github.com/fw876/helloworld)
- [kenzok8](https://github.com/kenzok8) 的 openwrt-packages 源
- [immortalwrt](https://github.com/immortalwrt) 的 CUPS 包
- GitHub Actions 免费编译资源
