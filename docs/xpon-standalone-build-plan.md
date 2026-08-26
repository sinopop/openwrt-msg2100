# econet-xpon 驱动单独编译方案

> 背景：MSG2100 已稳定运行新镜像。xpon 驱动（GPON 上行）按用户决定**单独编译**，
> 不编进主镜像。本文给出可执行的方案对比与推荐。

## 现状（2026-08-26 实测）

- econet-xpon 源码来源：AKoo7/openwrt@econet-xpon-gpon（PR #24577 未合并）
- workflow 目前只复制源码 + econet-eth 的 100-xpon-bench-spike.patch，**不编译**
- OpenWrt 新版用 **apk 打包**（不是 ipk）：产物为 `kmod-econet-xpon-6.18.44-r1.apk`
  （已从 32966782911 的 build.log 确认：`apk mkpkg ... --output .../packages/kmod-econet-xpon-6.18.44-r1.apk`）
- 设备端包管理器是 **apk**（`/usr/bin/apk`），内核 6.18.44 与构建一致
- xpon apk 依赖：`kernel=6.18.44~<hash>-r1 kmod-econet-eth`（econet-eth 需带 xpon patch 版）
- econet target 是 **source-only**：`bin/packages/` 可能不生成，ipk/apk 需从构建日志定位
- 设备当前镜像（32966782911）的 eth 驱动已含 xpon spike（dmesg: `xpon spike: PON QDMA engine enabled`）

## 方案对比

### 方案 A：主构建顺带编译 xpon（推荐）
在现有 workflow 的 Build 之后加一步，每次构建都产出 xpon .apk：
```yaml
- name: Build econet-xpon apk (standalone)
  run: |
    cd openwrt
    make package/kernel/econet-xpon/compile V=s 2>&1 | tee -a build.log || echo "XPON_BUILD_FAILED"
    mkdir -p ../xpon-pkgs
    find bin -name "*econet-xpon*.apk" -exec cp -v {} ../xpon-pkgs/ \; 2>/dev/null || true
    ls -la ../xpon-pkgs/ 2>/dev/null || echo "NO_XPON_APK"
```
- 前提：Configure 里加 `CONFIG_PACKAGE_kmod-econet-xpon=m`（否则 compile 是 no-op）
- Upload 增加 `xpon-pkgs/`
- 优点：构建环境复用（内核已编好，xpon 编译增量 ~1min）；每次 artifact 都带测试包
- 缺点：每次构建多 ~1-2 分钟（可忽略）；主镜像仍不含驱动（符合要求）

### 方案 B：独立 workflow_dispatch 手动触发
单独建 `build-xpon.yml`，仅当需要时才跑：
- 复用相同 clone/feeds/configure 流程，但只 `make package/kernel/econet-xpon/compile`
- 优点：平时主构建完全不受影响
- 缺点：需要完整重编内核环境（~50min），与主构建几乎同耗时；维护两套 workflow

### 方案 C：设备上编译
- 设备是 mipsel 无编译链，需交叉编译环境 → 实际不可行，排除

## 推荐：方案 A

理由：主构建本来就要跑 ~55min，xpon 增量编译只多 1-2 分钟；
每次 artifact 自带测试包，随取随用；一个 workflow 维护成本最低。

## 执行步骤（方案 A）

1. Configure 步骤加：`echo "CONFIG_PACKAGE_kmod-econet-xpon=m" >> .config`
2. Build 步骤后加 "Build econet-xpon apk" 步骤（见上）
3. Upload 加 `xpon-pkgs/`
4. 推送触发构建，artifact 里出现 `kmod-econet-xpon-6.18.44-r1.apk` + 带 patch 的 `kmod-econet-eth-*.apk`

## 安装测试（设备端）

```bash
# 传输（设备 IP 192.168.100.1，Mac 在 192.168.100.x）
scp kmod-econet-xpon-*.apk kmod-econet-eth-*.apk root@192.168.100.1:/tmp/
# 安装（apk 会校验 kernel 版本 hash，必须是同一次构建的产物）
apk add --allow-untrusted /tmp/kmod-econet-xpon-*.apk /tmp/kmod-econet-eth-*.apk
# 验证
lsmod | grep xpon
dmesg | grep -iE "xpon|gpon|ploam"
```
- 注意：apk 依赖 `kernel=6.18.44~<hash>-r1`，hash 来自构建配置；若设备镜像与 apk 非同次构建，
  需 `apk add --force-broken-world` 或用同次构建的镜像重刷
- 驱动加载方式：Makefile 注释说明 **无 AutoLoad**，需 econet-xpon-config 包提供 init.d 加载器
  （从 UCI 读 gpon_sn/gpon_pw/wan_mac）；完整 GPON 上网还需 OMCI daemon + 中国移动 LOID/authpwd

## 备选：直接从 GitHub Actions 缓存取 .apk

若不想重跑构建：32966782911 的 runner 已编译过 xpon（build.log 有 apk mkpkg 记录），
但 artifact 未上传该文件。可重新触发带方案 A 的构建获取。
