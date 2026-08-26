# MSG2100-UPON-AC 上游化提交清单（openwrt/openwrt）

> 目标：把 Raisecom MSG2100-UPON-AC 支持合入官方 openwrt/openwrt，
> 获得官方 commit hash → 填入 ToH 条目的 `Supported Since Commit`。
> 本机仓库 sinopop/openwrt-msg2100 基于上游 openwrt 构建，改动即待提交补丁。

## 一、上游现状核查（2026-08-26 实测）

- econet target 已存在：`target/linux/econet/`，SUBTARGETS = en751221/en751627/en7528，KERNEL_PATCHVER=6.18
- `package/kernel/econet-eth` 已存在，且是 `DEFAULT_PACKAGES`（上游默认包含）→ **我们的 device.mk 里的 `kmod-econet-eth` 冗余，可去掉**
- 上游已有 en7528 设备：Dasan H660GM-A、JioFiber JCOW407/JCOW414（均用 `Device/tclinux-ubi` + free bootbase）
- **上游 timer 驱动仍有 bug**（见下）
- 上游**无** msg2100（search: 0 命中）

## 二、需要提交的补丁（4 项）

### 1. DTS：`target/linux/econet/dts/en7528_raisecom_msg2100-upon-ac.dts`
本机：`en7528_raisecom_msg2100-upon-ac.dts`
- model/compatible: `raisecom,msg2100-upon-ac`, `econet,en7528`
- 内存：448MB + `linux,usable-memory-range=<0x20000 0x1bfe0000>`（**关键，直接映射 512MB 会挂死**）
- 分区：bootloader/romfile/tclinux(4M)/rootfs(217M UBI)/reservearea（5 分区，比原厂 11 分区精简）
- chosen: `bootargs="ubi.mtd=rootfs root=/dev/ubiblock0_0 rootfstype=squashfs"`
- gsw_port 标签：**印刷口1=lan1**（已对调，commit c515e74）
- pcie0/1 disabled（纯有线）、uart/gmac0/switch/nand okay、`econet,bmt` + bbt-table-size

### 2. timer 修复 patch：`target/linux/econet/patches-6.18/102-econet-timer-fix-block-mapping.patch`
本机：`102-timer-fix-block-mapping.patch`
- **上游缺失**：上游 101 patch 定义了 `ECONET_NUM_BLOCKS` 数组，但 timer_init() 仍用
  `num_blocks = DIV_ROUND_UP(num_possible_cpus(), 2)` 运行时计算（早期 SMP/VPE 下返回 1 → membase[1] NULL → panic）
- 修复：循环用 `ECONET_NUM_BLOCKS`（编译期 DIV_ROUND_UP(NR_CPUS,2)）
- 影响：**不只 msg2100**，en7528 全系列（含 Dasan/JioFiber）都可能受益，上游应该收

### 3. 设备定义：`target/linux/econet/image/en7528.mk` 追加
```make
define Device/raisecom_msg2100-upon-ac
  $(call Device/tclinux-ubi)
  DEVICE_VENDOR := Raisecom
  DEVICE_MODEL := MSG2100-UPON-AC
  DEVICE_DTS := en7528_raisecom_msg2100-upon-ac
  FACTORY_SIZE := 40m
  TRX_LOADADDR := 0x80002000
  KERNEL := kernel-bin | append-dtb | tclinux-free-bootbase-jump | lzma | \
    kernel-trx
endef
TARGET_DEVICES += raisecom_msg2100-upon-ac
```
- 去掉 `DEVICE_PACKAGES := kmod-econet-eth luci`（kmod-econet-eth 已是默认；luci 不属设备定义）
- jiofiber 先例：`TRX_LOADADDR := 0x80002000` + `tclinux-free-bootbase-jump`

### 4. （可选）econet-xpon 驱动
- 来源：AKoo7/openwrt@econet-xpon-gpon（PR #24577 未合并）
- 上游化需先与 AKoo7 协调，或作为独立 PR
- **不阻塞** msg2100 主支持；GPON 完整上网还需 OMCI daemon + LOID 认证，测试通过后再谈上游

## 三、提交前自检（对照上游惯例）

- [ ] DTS SPDX 头 `GPL-2.0-or-later` ✓（本机已带）
- [ ] device.mk 去冗余 DEVICE_PACKAGES
- [ ] 确认 FACTORY_SIZE=40m 与 tclinux 分区 4MB+rootfs 关系正确（tclinux.trx 写入 tclinux 分区 0x80000-0x480000）
- [ ] TRX 头校验：HDR2 magic + JAMCRC + LZMA 内核 + rootfs UBI（tclinux-trx.sh 已在上游）
- [ ] **分区机制澄清（已想通，无需改）**：
      bootloader 的 `flash xmdm tclinux` 用 **bootloader 内置分区表**（原厂 tclinux 40MB，
      0x80000 起）线性写入整个 8.78MB 镜像（HDR2+LZMA 内核+rootfs UBI）。
      `go` 启动 OpenWrt 内核后，**OpenWrt DTS 重新划分 NAND**：
      - 0x80000-0x480000 (4MB) = tclinux → 含镜像前 4MB（HDR2+内核）
      - 0x480000 起 = rootfs (217MB UBI) → 恰好接住镜像 0x480000 偏移处的 rootfs UBI 部分
      - 两段在物理上无缝衔接 → 无需扩容/两步刷
      FACTORY_SIZE=40m 是 bootloader 视角的原厂 tclinux 分区大小（镜像 8.78MB < 40MB 安全），
      与 OpenWrt 视角的 4MB tclinux 分区不冲突。jiofiber 同为 40m 先例。
- [ ] 提交信息遵循 OpenWrt 规范（"econet: add support for Raisecom MSG2100-UPON-AC"）
- [ ] 邮件列表发送前在 openwrt-devel 搜索是否有人已提交类似设备

## 四、FAQ

**Q: 为什么先上游化再建 ToH 条目？**
ToH 的 `Supported Since Commit` 需要官方 git commit 链接（如 dasan 的 8440e79），
自建仓库 commit 不算官方支持。上游合入 → 官方 snapshot 出镜像 → ToH 填 snapshot。

**Q: 官方 snapshot 镜像名会是什么？**
`openwrt-econet-en7528-raisecom_msg2100-upon-ac-squashfs-tclinux.trx`（与本地一致）

**Q: 时间预期？**
上游 econet target 已成熟（jiofiber/dasan 先例），timer 修复是亮点卖点，
预计提交后 1-2 个 release 周期内可合入（先 snapshot，后稳定版）。
