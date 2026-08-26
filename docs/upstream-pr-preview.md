# OpenWrt 上游化提交预览 — Raisecom MSG2100-UPON-AC

> 这是准备提交到 **openwrt/openwrt** 的完整内容预览。
> 请确认——尤其是 commit message / 设备描述文案。确认后我再生成最终 PR。
> 预计 4 个逻辑提交（见下）。若你想合并为 1 个提交，也请告知。

---

## 一、要提交的文件（3 个）

### 1. 新增 DTS：`target/linux/econet/dts/en7528_raisecom_msg2100-upon-ac.dts`
内容即本地 `en7528_raisecom_msg2100-upon-ac.dts`（已去掉本地注释里过长的 draft 说明，保留 header）。

**核对结果**：
- 引用的所有 label（`&uart` `&gmac0` `&switch` `&gsw_port1-4` `&nand` `&pcie0/1`）在上游 `en7528.dtsi` 中**全部存在** ✅
- `&nand { econet,bmt; econet,bbt-table-size = <163>; }` 与上游 `en7526f_chinamobile_gs3101.dts` 写法一致 ✅（同为中国移动设备）
- 端口标签：**印刷1口 = lan1**（gsw_port1→lan4, gsw_port2→lan3, gsw_port3→lan2, gsw_port4→lan1）

### 2. 追加设备定义到 `target/linux/econet/image/en7528.mk`
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
**改动点（相对本地构建版）**：删除 `DEVICE_PACKAGES := kmod-econet-eth luci`——
- `kmod-econet-eth` 已是上游 econet `DEFAULT_PACKAGES`（冗余）
- `luci` 不放设备级（上游惯例，jiofiber/dasan 都只放硬件驱动；luci 由用户按需装）
- 其余与本地版一致，且与上游 jiofiber（同为 free bootbase，`TRX_LOADADDR=0x80002000`）完全对齐 ✅

### 3. 新增 patch：`target/linux/econet/patches-6.18/102-econet-timer-fix-block-mapping.patch`
内容即本地 `102-timer-fix-block-mapping.patch`（去掉 `From: recovery` 占位）。
- 上游现有 `101-econet-timer-add-en7528-support.patch` **已定义 `ECONET_NUM_BLOCKS` 数组，但 timer_init() 仍用运行时 `DIV_ROUND_UP(num_possible_cpus(),2)`** → 我们的 fix 是必要补充
- 影响 en7528 全系（不只 msg2100），是提交的 **亮点卖点**

---

## 二、Commit Message（请确认文案）

### Commit 1 — DTS
```
mips: econet: add support for Raisecom MSG2100-UPON-AC

Add device tree for the Raisecom MSG2100-UPON-AC GPON ONT
(China Mobile, F.20/SC12).

SoC:        Econet/Airoha EN7528HU (MIPS 1004Kc, 2 cores 4 VPEs, 900MHz)
RAM:        512MB DDR3L (Samsung K4B4G1646B)
Flash:      Micron MT29F2G01 256MB SPI NAND
Ethernet:   4x 1Gbit (MT7530)
UART:       115200 8N1 on ttyS0
WLAN:       none (pure wired, 1x GPON + 4x GE)

Uses 448MB of RAM (top 64MB reserved for NAND/peripherals) with
linux,usable-memory-range = <0x20000 0x1bfe0000>. The stock bootloader
is TrendChip "free bootbase", kernel decompress addr 0x80002000.

Partition table is a trimmed 5-layout: bootloader / romfile /
tclinux (4MB kernel) / rootfs (217MB UBI) / reservearea.
```

### Commit 2 — 设备定义
```
econet: add Device profile for Raisecom MSG2100-UPON-AC

Add a tclinux-ubi image profile using free bootbase (TRX_LOADADDR
0x80002000), matching the JioFiber EN7528 devices.
```

### Commit 3 — timer 修复
```
mips: econet: timer: fix block mapping at boot for 4-VPE SoCs

timer_init() used DIV_ROUND_UP(num_possible_cpus(), 2) to size the
register-block loop. At early boot with VPE-based SMP, MIPS reports
num_possible_cpus()=1 (VPEs not yet online), so only membase[0] is
iomapped. The EN7528/EN751627 have 2 physical cores x 2 VPEs = NR_CPUS=4,
so cevt_dev_init(2) dereferences membase[1] == NULL -> kernel panic.

Use ECONET_NUM_BLOCKS (compile-time DIV_ROUND_UP(NR_CPUS,2), the same
expression that sizes the membase[] array) for both loops so the bound
and the array size are provably consistent.
```

---

## 三、PR 标题 / 描述（请确认）

**标题**：
```
econet: add support for Raisecom MSG2100-UPON-AC (GPON ONT)
```

**PR 正文**：
```
Adds support for the Raisecom MSG2100-UPON-AC, a China Mobile
(CMCC) custom GPON ONT (F.20/SC12), built on the Econet EN7528.

Highlights:
* Includes a timer bugfix for all EN7528/EN751627 4-VPE SoCs —
  the existing en7528 timer support still uses a runtime
  num_possible_cpus() that is wrong at early boot and NULL-derefs
  membase[1] on NR_CPUS=4 devices (see patch 102).
* Pure wired device: 4x GE via MT7530 + 1x GPON (xPON driver is a
  separate, not-yet-upstreamed module; GPON uplink is functional at
  the eth/PHY level but not activated without an OMCI daemon).
* Wired ports map so printed "1" = lan1 = WAN.

Tested: boots fully on 6.18, 4 CPUs up, LAN/WAN/LuCI working.
```

---

## 四、需要你确认/补充的事项

- [ ] **Commit Message 文案**是否OK（上面第二节）
- [ ] **PR 标题/描述**是否OK（上面第三节）
- [ ] **贡献者署名**：patch 里的 `From:` / commit `author` 用什么名字和邮箱？（上游 PR 需要真实署名，如 `yourname <you@example.com>`）
- [ ] **DTS header 注释**保留英文还是删减？（本地 header 较长，上游习惯精简）
- [ ] 提交粒度：**3 个提交**（DTS / 设备定义 / timer fix）还是合并为 **1 个**？
- [ ] 是否要我**把改动直接应用到本地 openwrt 工作副本并本地验证编译**，还是直接给 diff 你走 GitHub PR？

> 注意：我不会直接 push 到 openwrt/openwrt（那是官方仓库）。我会生成 diff + 分支，由你在 GitHub 提 PR，或先发到 openwrt-devel 邮件列表征询（上游惯例）。
