#!/bin/bash
# ==========================================
# feeds 配置：官方默认源 + kenzok8 全家桶 + helloworld + immortalwrt
# ==========================================

# 追加 kenzok8 的 openwrt-packages 源（大量实用包）
echo "src-git kenzo https://github.com/kenzok8/openwrt-packages.git" >> feeds.conf.default

# 追加 kenzok8 的 small 源（基础依赖包、科学上网插件）
echo "src-git small https://github.com/kenzok8/small.git" >> feeds.conf.default

# 追加 kenzok8 的 small-package 源（CUPS 等完整包）
echo "src-git smpackage https://github.com/kenzok8/small-package" >> feeds.conf.default

# 追加 helloworld 源（SSR-Plus 的原始来源）
echo "src-git helloworld https://github.com/fw876/helloworld" >> feeds.conf.default

# 追加 immortalwrt 源（完整 CUPS 打印包）
echo "src-git immortalwrt https://github.com/immortalwrt/packages.git;openwrt-24.10" >> feeds.conf.default

echo "✅ 已添加 kenzo、small、smpackage、helloworld、immortalwrt 源"
