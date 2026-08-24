# Windows 11 + WSL2 编译 OpenWrt（MSG2100-UPON-AC）

## 一、安装 WSL2 + Ubuntu（约 10 分钟）

**以管理员身份打开 PowerShell**，运行：
```powershell
wsl --install -d Ubuntu
```
重启电脑后，Ubuntu 会自动安装完成，设置 Linux 用户名/密码。

**确认版本**（在 Ubuntu 里）：
```bash
cat /etc/os-release   # 应显示 Ubuntu 22.04/24.04
```

## 二、安装编译依赖（在 Ubuntu 终端里）

```bash
sudo apt update
sudo apt install -y build-essential flex bison git rsync wget unzip \
    python3 python3-pip python3-distutils python3-setuptools \
    libncurses-dev zlib1g-dev libssl-dev libelf-dev file \
    gawk gettext quilt bc time subversion \
    libgmp-dev libmpc-dev libmpfr-dev \
    patchutils diffutils perl sed coreutils xz-utils
```

## 三、拉取源码 + 集成设备支持

```bash
cd ~
git clone https://github.com/openwrt/openwrt.git
cd openwrt
git pull   # 保持最新（econet/en7528 支持已合并主线）
```

**放入我们的 DTS**：
```bash
mkdir -p target/linux/econet/dts
# 把 en7528_raisecom_msg2100-upon-ac.dts 复制到这里
cp <你的路径>/en7528_raisecom_msg2100-upon-ac.dts target/linux/econet/dts/
```

**注册设备**（编辑 target/linux/econet/image/Makefile，参照 DASAN H660GM-A 的写法追加）：
```make
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
```

## 四、编译

```bash
# 更新 feeds（必须）
./scripts/feeds update -a
./scripts/feeds install -a

# 选择配置
make menuconfig
#  Target System: 选 Econet EN75xx MIPS
#  Subtarget:      en7528
#  Target Profile: Raisecom MSG2100-UPON-AC
#  建议最小化：取消不需要的包（可先在 Target Profile 里勾选）
# 保存退出

# 开始编译（16G 内存可 -j8，首次编译约 1~3 小时）
make -j$(nproc) V=s | tee build.log
```

## 五、产物

```
bin/targets/econet/en7528/
  openwrt-econet-en7528-raisecom_msg2100-upon-ac-squashfs-tclinux.trx   ← 刷机用（40MB 分区）
  openwrt-econet-en7528-raisecom_msg2100-upon-ac-initramfs-kernel.bin   ← RAM 启动测试用
```

## 六、刷入（root shell 方法，双分区安全）

1. 把 tclinux.trx 通过 HTTP 放到设备 /www/tmp（root shell 里 `dd` 从 /dev/mtd* 已证明可行）
2. root shell 中：
   ```sh
   dd if=/www/tmp/openwrt.trx of=/dev/mtd7    # 写 slave 分区（原厂在 mtd4 不动）
   ```
3. 切换启动标志到 slave → 重启
4. 串口观察 OpenWrt 启动；出问题切回 mtd4

> ⚠️ 首次刷机建议先试 **initramfs-kernel.bin**（RAM 启动，不写 flash，零风险）：
> 从 root shell 或 bootloader（xmdm+jump 0x80002000）加载测试，确认内核能起再写分区。

## 七、注意事项

- **GPON 上网**：主线 OpenWrt 的 EN7528 GPON 驱动还在 PR 阶段（#24577），OpenWrt 下暂时无法通过 PON 上网；日常上网用原厂固件（双分区切换）
- 本机是 **free bootbase** bootloader（内核解压地址 0x80002000，不是默认的 0x80020000）——设备定义里已处理
- 分区表：tclinux = 0x80000-0x2880000（40MB）；slave = 0x2880000-0x5080000
- DTS 中的 GPIO（LED 等）是草稿，未实机验证；LAN 口（gsw_port1-4）和 UART 已按实测配置
