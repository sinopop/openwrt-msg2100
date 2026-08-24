# GitHub Actions 云端构建 OpenWrt（MSG2100-UPON-AC）

用 GitHub 免费云端 runner 编译 OpenWrt，**完全不占用本地资源**。

## 准备工作（5 分钟）

1. 注册免费 GitHub 账号：https://github.com/signup
2. 新建仓库（New repository）：
   - 名字随意，如 `openwrt-msg2100`
   - 选 **Public** 或 Private 都行（Private 免费版每月也有 Actions 额度，Public 完全免费不限）
   - **不要**勾选 "Add a README"（保持空仓库）

## 上传文件

在 Mac 上执行（把 `openwrt/` 目录推送到 GitHub）：
```bash
cd /Users/mac/Documents/dsh/openwrt

# 初始化 git
git init
git add .
git commit -m "MSG2100-UPON-AC OpenWrt build"

# 关联你的仓库（把 USER 换成你的 GitHub 用户名）
git remote add origin https://github.com/USER/openwrt-msg2100.git
git branch -M main
git push -u origin main
```

推送后 GitHub 会提示输入用户名 + **Personal Access Token**（Settings → Developer settings → Personal access tokens → Generate new token，勾选 `repo` 权限，复制粘贴）。

## 触发构建

1. 打开仓库页面 → **Actions** 标签 → 左侧 `Build OpenWrt MSG2100-UPON-AC` → **Run workflow** 按钮
2. 等 1~3 小时（首次编译）
3. 构建完成 → 进入该次运行 → **Artifacts** 区下载 `openwrt-msg2100` 压缩包

## 产物说明

| 文件 | 用途 |
|---|---|
| `openwrt-econet-en7528-raisecom_msg2100-upon-ac-squashfs-tclinux.trx` | **刷机镜像**（写 mtd7 用） |
| `openwrt-econet-en7528-raisecom_msg2100-upon-ac-initramfs-kernel.bin` | RAM 启动测试用（不写 flash，零风险） |
| `build.log` | 编译日志（报错时查看/反馈） |
| `.config` | 本次编译配置 |

## 修改后重新构建

改完 DTS 重新 push 即可，或在 Actions 页面手动再次 Run workflow。首次之后的增量编译会快很多（有 ccache 的话更快——需要时在 workflow 里加 ccache 步骤）。

## 常见问题

- **构建失败**：把 `build.log` 里 `ERROR`/`Error` 附近内容发我
- **找不到设备**：`grep raisecom .config` 确认设备已选上；若报错说明设备定义注入有问题
- **磁盘空间**：GitHub runner 有 14GB 临时盘，OpenWrt 完整构建约需 10GB，够用；如空间不足可在 workflow 加 `df -h` 排查
