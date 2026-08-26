# ToH 设备条目准备：Raisecom MSG2100-UPON-AC

> OpenWrt Table of Hardware (ToH) 数据源：https://openwrt.org/toh.json （每日由 hwdata 页面扫描生成）
> 参考模板设备：Dasan H660GM-A（同为 EcoNet EN7528 SoC，econet/EN7528 target）
> 参考模板设备：CMCC 系列（同为中国移动运营商设备，看其字段写法）

## 一、设备基本信息

| 项目 | 值 | 来源/说明 |
|---|---|---|
| Brand | Raisecom（瑞斯康达） | 设备标签 |
| Model | MSG2100-UPON-AC | 设备标签 |
| Version | 中国移动四川 F.20/SC12 | DTS 注释 |
| Device Type | Router | 纯有线 GPON ONT，无 WiFi |
| Device Page | `toh:raisecom:msg2100-upon-ac` | 计划创建的 wiki 页面 |
| Where available | China | 中国移动运营商集采 |

## 二、硬件规格（已实测确认）

| 字段 | 值 | 实测来源 |
|---|---|---|
| CPU | EcoNet/Airoha EN7528HU | `cat /proc/cpuinfo` → `EcoNet-EN75xx` |
| CPU Cores | 2 | cpuinfo processor 0/1 |
| CPU MHz | 900 | DTS 注释 + cpuinfo BogoMIPS 597.60 (1004Kc @~900MHz) |
| Package architecture | `mipsel_24kc` | `/etc/openwrt_release` → DISTRIB_ARCH |
| Target / Subtarget | `econet` / `EN7528` | `/etc/openwrt_release` → DISTRIB_TARGET |
| RAM MB | 512 (DDR3L) | 硬件规格 K4B4G1646B；meminfo MemTotal 442744kB（DTS 限 448MB） |
| Flash MB | 256 (SPI NAND) | dmesg: Micron SPI NAND 256MiB, MT29F2G01 |
| Switch | MT7530 | mdio_bus: mt7530-0:09..0c；DTS `&switch` |
| Ethernet 1Gbit ports | 4 | gsw_port1-4 → lan1-4；前面板 LAN1-LAN4 |
| Ethernet 100M ports | 0 | — |
| WLAN | 无（纯有线） | DTS 无 wifi 节点，`&pcie0/1 disabled` |
| Modem | 1x GPON 上行（econet-xpon，测试中） | PON 蓝口（SC/APC）；OpenWrt 下驱动待测试 |
| Phone ports | 0 | 纯数据 ONT |
| USB ports | 0 | DTS 无 USB；纯有线设备 |
| SATA/SFP/Video/Audio | 0 | — |
| Bootloader | other（TrendChip TcBoot free bootbase v1.1） | 引导输出；ToH 枚举无对应项，填 "other" |
| Serial | Yes | UART @ 0x1fbf0000, ttyS0 |
| Serial connection parameters | 115200 / 8N1 | DTS stdout-path |
| Serial connection voltage | 3.3V | Econet SoC 标准 UART |
| JTAG | 未知 | — |
| GPIOs | 未知 | gpiochip0/1 存在 |
| LED count | 4 | 前面板：PON、SYS、LOS、PWR（照片确认） |
| Button count | 1（RST 复位键）+ 1 电源开关 | 前面板 RST 小孔 + PWR 电源按钮 |
| Power Supply | +12V, 1A | 适配器 + 贴纸「额定输入：+12V,1A」 |
| Outdoor | No | 室内 ONT（中国移动政企网关） |

## 三、固件与支持状态

| 字段 | 值 | 说明 |
|---|---|---|
| Supported Current Rel | snapshot | 当前为自建 SNAPSHOT（非官方） |
| Supported Since Commit | 待定 | 上游 openwrt/openwrt 合入后填 commit 链接；当前仓库 sinopop/openwrt-msg2100 |
| Supported Since Rel | 待定 | 同上 |
| Installation method(s) | Serial | 串口 + bootloader `xmdm`（Xmodem 刷 tclinux 分区） |
| Recovery method(s) | Serial | bootloader Xmodem 重刷；内核 panic 后重启循环可 Ctrl+D 进 bldr> |
| Firmware OpenWrt Install URL | 待填 | 上游化后官方 downloads 链接；当前为自建 artifacts |
| Firmware OEM Stock URL | 无公开 | 运营商定制固件不外发（中国移动集采） |
| OEM Device Homepage URL | 待查 | Raisecom（瑞斯康达）官网产品页 |
| OWrt Forum Topic URL | 待建 | 建议在 forum.openwrt.org 发介绍帖 |

## 三·b、设备贴纸信息（标签照片确认）

| 项目 | 值 |
|---|---|
| 品牌 | RAISECOM（瑞斯康达科技发展股份有限公司，中国制造） |
| 设备名称 | 集客融合接入设备 |
| 设备类型 | 中国移动政企网关设备（GPON版 4+0） |
| 型号 | MSG2100-UPON-AC |
| 版本 | F.20(SC12) |
| 额定输入 | +12V, 1A |
| 生产日期 | 2022-08-25 |
| 默认终端账号 | user（默认终端配置地址 192.168.1.1） |
| 进网许可证 | CNA 12-8445-191492 |
| 设备标识/GPON SN/LAN MAC | 已打码（隐私） |
| 运营商 | 中国移动通信集团终端有限公司（服务热线 10086） |

## 四、安装/恢复说明（供 wiki 页面用）

### 安装（Serial）
1. 接串口：GND/TX/RX（3.3V TTL），115200 8N1
2. 上电，启动阶段按 **Ctrl+D** 进入 bootloader 命令模式（bldr>），凭据 `admin`/`admin`
3. 使用 `xmdm` 命令 + Xmodem-CRC（128 字节块）把 OpenWrt `.trx` 镜像写入 tclinux 分区：
   - `flash xmdm tclinux`（以实际命令为准）
   - 约 8.8MB @ 7.8KB/s ≈ 18-20 分钟
4. `go` 启动，内核从 tclinux 分区解压（decompress addr 0x80002000）

### 恢复
- 内核/rootfs 损坏时设备进入重启循环，按 Ctrl+D 进 bldr> 重刷即可
- bootloader 看门狗不复位（已验证 bldr> 停留 60+ 分钟无问题）
- **bootloader 命令注意**：`memwl`/`memrl`/`xmdm` 等命令的 hex 解析器**不认 "0x" 前缀**，需用裸十六进制

### 重要提醒
- rootfs 为 UBI 卷上的 squashfs（`root=/dev/ubiblock0_0 rootfstype=squashfs`）
- DTS 内存节点：448MB + `linux,usable-memory-range=<0x20000 0x1bfe0000>`（512MB 直接映射会挂死）
- 端口映射（最新修正）：**印刷口 1 = lan1**（DTS 已对调标签，commit c515e74）

## 五、信息收集状态（大部分已确认）

**已确认（黄色标注为已填）**：
- [x] 设备照片（正面/背面/标签）→ `/Users/mac/Documents/dsh/photos/{front,back,label}.heic`（转 jpg 在 photos/）
- [x] 电源适配器规格：**+12V, 1A**（贴纸「额定输入：+12V,1A」+ 适配器）
- [x] 面板 LED 数量：**4 个**（PON、SYS、LOS、PWR，正面照片确认）
- [x] 按钮：RST 复位键（小孔）+ PWR 电源开关
- [x] 设备标签型号/版本：**MSG2100-UPON-AC, F.20(SC12), 生产日期 2022-08-25**
- [x] 进网许可证：CNA 12-8445-191492；品牌 RAISECOM/瑞斯康达科技发展股份有限公司
- [x] 默认终端地址 192.168.1.1，账号 user

**待确认**：
- [ ] 串口电压实测 3.3V（万用表量测，当前按 SoC 标准 3.3V 填）
- [ ] Raisecom 官网产品页 URL（如有）
- [ ] 是否申请 openwrt.org wiki 账号（用于创建 `toh:raisecom:msg2100-upon-ac` 设备页）

> 隐私提醒：标签上的 GPON SN、LAN MAC、设备标识、SN 已被打码，上传到 openwrt.org 时**不要包含**这些敏感信息。

## 六、ToH 提交流程（待设备上游化后）

1. **上游合入 openwrt/openwrt**：提交 target/linux/econet 的 DTS + image/Makefile 设备定义 + 102-timer-fix patch（若未合入），得到官方 commit hash
2. **创建 wiki 设备页** `toh:raisecom:msg2100-upon-ac`，按 hwdata 格式填写所有字段（见上表）
3. **上传图片**到 media:raisecom/
4. **发论坛帖** forum.openwrt.org 介绍设备支持情况，获得 topic URL
5. 等 nightly 扫描把页面数据并入 toh.json，设备即出现在 ToH 表中

## 七、toh.json 字段清单（全部字段，未填的标 -）

Device ID: raisecom:raisecom_msg2100-upon-ac
Audio ports: -
Availability: 待定（中国移动集采，可填 "Available" 或 "unknown 2026"）
Bluetooth: -
Bootloader: other
Brand: Raisecom
Button count: 待确认
CPU: EcoNet EN7528HU
CPU Cores_numcores: 2
CPU MHz: 900
Comment installation: 见 wiki 页面（串口 Xmodem）
Comment recovery: 见 wiki 页面（bootloader 重刷）
Comments: 纯有线 GPON ONT；无 WiFi/USB；中国移动定制
Comments AV ports: -
Comments USB SATA ports: -
Comments network ports: 印刷口1=WAN(lan1)；其余 2-4 为 LAN
Detachable Antennas: No
Device Page: toh:raisecom:msg2100-upon-ac
Device Type: Router
Ethernet 100M ports: -
Ethernet 10Gbit ports: -
Ethernet 1Gbit ports: 4
Ethernet 2.5Gbit ports: -
Ethernet 5Gbit ports: -
FCCID: -
Firmware OEM Stock URL: -
Firmware OpenWrt Install URL: 待上游化后填
Firmware OpenWrt Upgrade URL: 待上游化后填
Firmware OpenWrt snapshot Install URL: 待上游化后填
Firmware OpenWrt snapshot Upgrade URL: 待上游化后填
Flash MB: ['256']
Forum search: ['MSG2100-UPON-AC']
GPIOs: 未知
Git search: ['MSG2100-UPON-AC']
Installation method(s): ['Serial']
JTAG: 未知
LED count: 4
Model: MSG2100-UPON-AC
Modem: -
OEM Device Homepage URL: 待查
OWrt Forum Topic URL: 待建
Outdoor: No
Package architecture: mipsel_24kc
Phone ports: -
Picture: ['media:raisecom:msg2100-upon-ac.jpg']
Power Supply: 12VDC, 1A
RAM MB: 512
Recovery method(s): ['Serial']
SATA ports: -
SFP ports: -
SFP+ ports: -
Serial: Yes
Serial connection parameters: 115200 / 8N1
Serial connection voltage: 3.3
Subtarget: EN7528
Supported Current Rel: snapshot
Supported Since Commit: 待上游 commit
Supported Since Rel: 待上游 release
Switch: MT7530
Target: econet
USB ports: -
Unsupported Functions: GPON 上行在 OpenWrt 下暂不可用（econet-xpon 驱动未集成；用户决定等上游 PR 接受后再做）
VLAN: 待确认
Video ports: -
WLAN 2.4GHz: -
WLAN 5.0GHz: -
WLAN 6.0GHz: -
WLAN 60.0GHz: -
WLAN Comments: -
WLAN Hardware: -
WLAN driver: -
Where available: China
WikiDevi URL: -
