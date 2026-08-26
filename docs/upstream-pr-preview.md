# OpenWrt upstream submission — Raisecom MSG2100-UPON-AC

> Complete upstream PR preview for **openwrt/openwrt**.
> Contributor: sinopop <sinomaxpop@gmail.com>
> Split into **3 logical commits** (DTS / device profile / timer fix).
>
> This is a preview for your review. Once approved I will prepare the
> diff / branch to open a PR (or post to openwrt-devel first, per project
> convention).

---

## 1. Files to submit (3)

### 1.1 New DTS: `target/linux/econet/dts/en7528_raisecom_msg2100-upon-ac.dts`

```dts
// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Raisecom MSG2100-UPON-AC (China Mobile, F.20/SC12)
 * SoC: Econet/Airoha EN7528HU (MIPS 1004Kc, LE, 900MHz)
 * RAM: 512MB DDR3L (Samsung K4B4G1646B)
 * Flash: Micron MT29F2G01 256MB SPI NAND (2048+64B pages, 128KB blocks)
 * WiFi: none (pure wired: 1x GPON + 4x GE)
 * UART: 115200 8N1, console on ttyS0 (Econet UART @ 0x1fbf0000)
 */

/dts-v1/;

#include "en7528.dtsi"

/ {
	model = "Raisecom MSG2100-UPON-AC";
	compatible = "raisecom,msg2100-upon-ac", "econet,en7528";

	memory@0 {
		device_type = "memory";
		reg = <0x00000000 0x1c000000>;	/* 448MB (top 64MB is NAND/peripherals) */
	};

	chosen {
		stdout-path = "serial0:115200n8";
		linux,usable-memory-range = <0x00020000 0x1bfe0000>;
		bootargs = "ubi.mtd=rootfs root=/dev/ubiblock0_0 rootfstype=squashfs";
	};

	aliases {
		serial0 = &uart;
	};
};

&uart {
	status = "okay";
};

&gmac0 {
	status = "okay";
};

&switch {
	status = "okay";
};

&gsw_port1 {
	label = "lan4";
	status = "okay";
};

&gsw_port2 {
	label = "lan3";
	status = "okay";
};

&gsw_port3 {
	label = "lan2";
	status = "okay";
};

&gsw_port4 {
	label = "lan1";
	status = "okay";
};

/* No WiFi / PCIe on this wired-only device */
&pcie0 {
	status = "disabled";
};

&pcie1 {
	status = "disabled";
};

&nand {
	status = "okay";
	econet,bmt;
	econet,bbt-table-size = <163>;

	partitions {
		compatible = "fixed-partitions";
		#address-cells = <1>;
		#size-cells = <1>;

		partition@0 {
			label = "bootloader";
			reg = <0x0 0x40000>;
			read-only;
		};

		partition@40000 {
			label = "romfile";
			reg = <0x40000 0x40000>;
			read-only;
		};

		partition@80000 {
			label = "tclinux";
			reg = <0x80000 0x400000>;
			econet,enable-remap;
		};

		partition@480000 {
			label = "rootfs";
			reg = <0x480000 0xd940000>;
			econet,enable-remap;
		};

		partition@ddc0000 {
			label = "reservearea";
			reg = <0xddc0000 0x240000>;
			read-only;
		};
	};
};
```

> Header trimmed to the essential hardware summary. The long stock
> partition comment was dropped (stock layout is not used; the trimmed
> 5-partition layout is self-documenting in the node).
> Port labels map so the physically printed "1" = lan1 = WAN.

### 1.2 Append to `target/linux/econet/image/en7528.mk`

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

> Dropped `DEVICE_PACKAGES := kmod-econet-eth luci` vs. the local build:
> - `kmod-econet-eth` is already in the econet `DEFAULT_PACKAGES`.
> - `luci` is not a device-level package (matches jiofiber/dasan; users add it).
> `TRX_LOADADDR := 0x80002000` matches the JioFiber EN7528 free-bootbase
> devices.

### 1.3 New patch: `target/linux/econet/patches-6.18/102-econet-timer-fix-block-mapping.patch`

```patch
From: sinopop <sinomaxpop@gmail.com>
Subject: mips: econet: timer: fix timer block mapping at boot

timer_init() used DIV_ROUND_UP(num_possible_cpus(), 2) to determine how
many register blocks to iomap. At early boot with VPE-based SMP, MIPS
reports num_possible_cpus()=1 (VPEs not yet brought online), giving
num_blocks=1. Only membase[0] is then mapped via of_iomap.

The EN7528/EN751627 SoCs have 2 physical cores, each with 2 VPEs, giving
NR_CPUS=4 and two timer register blocks (one per core). cevt_init()
calls cevt_dev_init(i) for each possible CPU; with NR_CPUS=4,
cevt_dev_init(2) writes to reg_compare(2) which dereferences
membase[2>>1] = membase[1], which is NULL, causing a kernel panic.

Fix: replace the runtime calculation with ECONET_NUM_BLOCKS, which is
DIV_ROUND_UP(NR_CPUS, 2) evaluated at compile time (same expression used
to declare the membase[] array), so the loop bound and array size are
provably consistent.

--- a/drivers/clocksource/timer-econet-en751221.c
+++ b/drivers/clocksource/timer-econet-en751221.c
@@ -201,6 +201,5 @@ static int __init timer_init(struct device_node *np)
 static int __init timer_init(struct device_node *np)
 {
-	int num_blocks = DIV_ROUND_UP(num_possible_cpus(), 2);
 	struct clk *clk;
 	int ret, i;
 
@@ -260,6 +259,6 @@ static int __init timer_init(struct device_node *np)
 	econet_timer.freq_hz = clk_get_rate(clk);
 
-	for (i = 0; i < num_blocks; i++) {
+	for (i = 0; i < ECONET_NUM_BLOCKS; i++) {
 		econet_timer.membase[i] = of_iomap(np, i);
 		if (!econet_timer.membase[i]) {
 			pr_err("%pOFn: failed to map register [%d]\n", np, i);
@@ -296,5 +295,5 @@ static int __init timer_init(struct device_node *np)
 err_unmap:
-	for (i = 0; i < num_blocks; i++) {
+	for (i = 0; i < ECONET_NUM_BLOCKS; i++) {
 		if (econet_timer.membase[i])
 			iounmap(econet_timer.membase[i]);
 	}
```

> This is a real bugfix for all EN7528/EN751627 4-VPE SoCs, not just this
> board — the existing 101-econet-timer-add-en7528-support.patch defines the
> `ECONET_NUM_BLOCKS` array but timer_init() still uses the runtime
> `num_possible_cpus()`.

---

## 2. Commit messages

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

### Commit 2 — device profile
```
econet: add Device profile for Raisecom MSG2100-UPON-AC

Add a tclinux-ubi image profile using free bootbase (TRX_LOADADDR
0x80002000), matching the JioFiber EN7528 devices.
```

### Commit 3 — timer fix
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

## 3. PR title / description

**Title**:
```
econet: add support for Raisecom MSG2100-UPON-AC (GPON ONT)
```

**Body**:
```
Adds support for the Raisecom MSG2100-UPON-AC, a China Mobile
(CMCC) custom GPON ONT (F.20/SC12), built on the Econet EN7528.

Highlights:
* Includes a timer bugfix for all EN7528/EN751627 4-VPE SoCs —
  the existing en7528 timer support still uses a runtime
  num_possible_cpus() that is wrong at early boot and NULL-derefs
  membase[1] on NR_CPUS=4 devices (see patch 102).
* Pure wired device: 4x GE via MT7530 + 1x GPON (xPON driver is a
  separate, not-yet-upstreamed module; GPON uplink functional at the
  eth/PHY level but not activated without an OMCI daemon).
* Wired ports map so printed "1" = lan1 = WAN.

Tested: boots fully on kernel 6.18, 4 CPUs up, LAN/WAN/LuCI working.

Signed-off-by: sinopop <sinomaxpop@gmail.com>
```

---

## 4. Pre-submit checklist

- [x] All DTS label references exist in upstream `en7528.dtsi`
- [x] `econet,bmt` written like upstream `en7526f_chinamobile_gs3101.dts`
- [x] Device profile aligns with upstream JioFiber free-bootbase devices
- [x] Timer fix confirmed missing upstream (101 patch still uses runtime calc)
- [x] 3 commits, contributor `sinopop <sinomaxpop@gmail.com>`
- [ ] Local compile validation (pending — will apply to a working tree)
- [ ] Post to openwrt-devel ML, then open PR (per project convention)

> I will NOT push directly to openwrt/openwrt. I will prepare the diff /
> branch for you to open the PR, or post to openwrt-devel first.
