#!/bin/bash
# ============================================================
# OpenWrt 一键构建脚本 - Raisecom MSG2100-UPON-AC (EN7528)
# 用法: bash build-msg2100.sh [--fresh]
# 前提: Ubuntu (WSL2/VM)，已装 build-essential 等依赖
# 产物: bin/targets/econet/en7528/*.trx
# ============================================================
set -e

OPENWRT_DIR="$HOME/openwrt-msg2100"
JOBS=$(nproc)
FRESH=0
[ "$1" == "--fresh" ] && FRESH=1

echo "=== [1/5] 拉取 OpenWrt 源码 ==="
if [ ! -d "$OPENWRT_DIR/.git" ]; then
    git clone https://github.com/openwrt/openwrt.git "$OPENWRT_DIR"
fi
cd "$OPENWRT_DIR"
git pull || true

echo "=== [2/5] 集成 MSG2100-UPON-AC 设备支持 ==="
DTS_SRC="$(cd "$(dirname "$0")" && pwd)/en7528_raisecom_msg2100-upon-ac.dts"
mkdir -p target/linux/econet/dts
cp "$DTS_SRC" target/linux/econet/dts/

# 注入设备定义（幂等：已存在则跳过）
if ! grep -q "raisecom_msg2100-upon-ac" target/linux/econet/image/Makefile; then
    cat >> target/linux/econet/image/Makefile <<'EOF'

# ==== Raisecom MSG2100-UPON-AC (free bootbase: load addr 0x80002000) ====
define Device/raisecom_msg2100-upon-ac
  DEVICE_VENDOR := Raisecom
  DEVICE_MODEL := MSG2100-UPON-AC
  DEVICE_DTS := en7528_raisecom_msg2100-upon-ac
  KERNEL_LOADADDR := 0x80002000
  KERNEL_SIZE := 4096k
  KERNEL := kernel-bin | append-dtb | lzma | kernel-trx | tclinux-free-bootbase-jump
  KERNEL_INITRAMFS := kernel-bin | append-dtb
  IMAGES := tclinux.trx sysupgrade.bin
  IMAGE/tclinux.trx := append-kernel | pad-to $$$$(KERNEL_SIZE) | append-ubi | check-size 40m
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
  DEVICE_PACKAGES := kmod-econet-eth
endef
TARGET_DEVICES += raisecom_msg2100-upon-ac
EOF
    echo "   设备定义已注入 image/Makefile"
else
    echo "   设备定义已存在，跳过"
fi

echo "=== [3/5] feeds ==="
./scripts/feeds update -a
./scripts/feeds install -a

echo "=== [4/5] 配置 ==="
if [ $FRESH -eq 1 ] || [ ! -f .config ]; then
    # 基础配置：econet/en7528 + 我们的设备
    cat > .config <<'CFG'
CONFIG_TARGET_econet=y
CONFIG_TARGET_econet_en7528=y
CONFIG_TARGET_econet_en7528_DEVICE_raisecom_msg2100-upon-ac=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CFG
    make defconfig
    # 如需要自定义包，取消下面注释手动配置：
    # make menuconfig
fi

echo "=== [5/5] 编译 (-j$JOBS) ==="
make -j"$JOBS" V=s 2>&1 | tee build-msg2100.log

echo ""
echo "=========================================="
echo "构建完成！产物："
ls -la bin/targets/econet/en7528/*.trx bin/targets/econet/en7528/*initramfs* 2>/dev/null || true
echo "=========================================="
