# econet-xpon 驱动测试计划（MSG2100-UPON-AC GPON 上行）

> 方案：**单独安装 .ipk**（不进主镜像）——已实现于 workflow（commit f5a304c）
> 镜像含 4MB 空闲 rootfs 空间（squashfs+overlay），可安全装/卸驱动测试

## 一、背景与目标

- MSG2100-UPON-AC 是 GPON ONT：1x SC/APC PON 光纤上行 + 4x GE LAN
- OpenWrt 下 LAN/WAN 已完全工作（LAN1=WAN 走以太网上行，见 notes）
- 目标：让 **GPON 光纤上行**在 OpenWrt 下工作（注册到 OLT + 拨号）
- 驱动来源：AKoo7/openwrt@econet-xpon-gpon（PR #24577 未合并）+ econet-eth 的 100-xpon-bench-spike.patch

## 二、前置条件（已具备）

- [x] 设备运行 OpenWrt 6.18.44（root shell、串口可用）
- [x] 构建环境已含 econet-xpon 源码（workflow 复制自 AKoo7 PR）
- [x] workflow 会单独编译 .ipk 并上传 artifact（32961562796）
- [x] 串口脚本 /tmp/flash_only.py、/tmp/catch_bldr.py 可用
- [ ] 光纤已插入 PON 口（用户操作）
- [ ] 中国移动 LOID / authpwd（原厂 env: authloid=p, authpwd=p —— 从原厂固件提取，测试时可能需真实值）

## 三、测试步骤

### 1. 获取 ipk
- artifact 下载目录：/tmp/artifacts-final/
- 预期文件：`bin/packages/mipsel_24kc/kernel/econet-xpon_*.ipk`
- 检查依赖：`opkg depends kmod-econet-xpon`（可能需要 econet-eth 补丁版内核模块）

### 2. 传输到设备
```bash
# Mac 上，串口转 SSH? 设备无 SSH 服务，用串口 + base64 或先开 dropbear
# 简单方案：通过 LuCI/SCP 不可用 → 用串口 zmodem 或:
#   a) 在设备上先装 dropbear: opkg update && opkg install dropbear
#   b) scp 到 192.168.100.1（Mac 需在 192.168.100.x）
scp econet-xpon_*.ipk root@192.168.100.1:/tmp/
```

### 3. 安装
```bash
opkg install /tmp/econet-xpon_*.ipk
# 若报内核版本依赖错误，需 --force-depends（内核为自建版本）
lsmod | grep -i xpon
dmesg | grep -iE "xpon|gpon|ploam"
```

### 4. 驱动加载验证
- 检查 /sys/class 下是否有 xpon 相关设备节点
- 检查内核日志：GPON 物理层（PON PHY）是否探测到
- 若驱动内置自测（100-xpon-bench-spike.patch）：观察 bench 输出

### 5. 光纤注册（需真实 LOID）
- 原厂认证参数：authloid=p, authpwd=p（从 showenv 得到，需替换为实际值）
- OMCI daemon：PR #24577 可能只含驱动，不含 OMCI 协议栈
- 若只有驱动无 OMCI：能验证到 PLoAM 注册（物理层），无法完整上网

### 6. 回滚
```bash
opkg remove kmod-econet-xpon   # 或重启即卸载（驱动不持久化）
```

## 四、风险与注意事项

1. **内核版本匹配**：ipk 是针对当前内核 6.18.44 编译的，重刷镜像后需重装
2. **驱动冲突**：econet-eth 的 100-xpon-bench-spike.patch 修改了 eth 驱动，
   若测试异常可能导致 LAN 口掉线 —— 测试时保持串口在线
3. **注册不上 OLT 是正常的**：没有 OMCI + 正确 LOID，GPON 不会完整激活，
   先验证物理层（RX 光功率、PLOAM 响应）即可
4. **不要拔光纤带电操作**（GPON 激光安全）

## 五、验收标准

- [ ] `opkg install` 成功，`lsmod` 看到 econet_xpon
- [ ] dmesg 出现 xpon/gpon 相关 probe 日志
- [ ] 若有 OMCI：注册状态机走到 O5（Operating）
- [ ] 完整测试（拨号上网）暂缓：需 OMCI daemon + 真实 LOID

## 六、与 ToH 的关系

- xpon 测试成功 → Unsupported Functions 字段可填 "GPON 上行待 OMCI"
- 驱动上游化需与 AKoo7 协调（PR #24577），不阻塞 msg2100 主支持
