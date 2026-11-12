# debian-mirror-speedtest

> 🚀 Debian 镜像源测速与一键配置工具 —— 支持 Linux (Bash) 与 Windows (PowerShell)

一个用于 **Debian 及其衍生发行版** 的镜像源测速脚本集合。它会自动探测国内主流镜像站的 **TCP 连通性、元数据有效性、下载速度与延迟**，并可根据结果一键把系统软件源切换到最快的镜像。

两个脚本分工明确：

- **Linux 版 `debian_Mirror_Test.sh`**：在 **已装好的 Debian 系统内** 运行，测速后自动备份并改写 `/etc/apt/sources.list`，执行 `apt update`，一步到位。
- **Windows 版 `Debian_Mirror_Test.ps1`**：主要用于 **在虚拟机里安装 Debian 时** 挑选临时仓库源的场景。安装器（Debian Installer）会要求填写镜像地址，此时在 Windows 宿主机上跑这个脚本，快速判断哪个源可用、哪个快，把结果填进安装界面即可。**一般先填官方调度源 `ftp.cn.debian.org`**（会自动就近重定向，最稳妥），等系统装好进桌面后，再下载 `.sh` 脚本做正式的自动配置与精调。

- 仓库地址：<https://github.com/HonKer-Dynamo/debian-mirror-speedtest>
- 适用系统：Debian 10 / 11 / 12 / 13 (buster / bullseye / bookworm / trixie) 及衍生版
- 脚本语言：Bash、PowerShell

---

## 📢 重要提示：请下载单个脚本文件，不要克隆仓库

本仓库只是脚本集合，**不需要 `git clone`**。你只需要下载自己需要的那个脚本文件即可：

| 平台           | 文件                                                         | 典型用途                               |
| -------------- | ------------------------------------------------------------ | -------------------------------------- |
| Linux / Debian | [`debian_Mirror_Test.sh`](https://github.com/HonKer-Dynamo/debian-mirror-speedtest/blob/main/debian_Mirror_Test.sh) | 系统装好后一键测速并切换软件源         |
| Windows        | [`Debian_Mirror_Test.ps1`](https://github.com/HonKer-Dynamo/debian-mirror-speedtest/blob/main/Debian_Mirror_Test.ps1) | 虚拟机安装 Debian 时辅助选择临时安装源 |

下面的“快速开始”提供了 `wget` / `curl` / PowerShell 的直接下载命令。

> 如果仓库默认分支不是 `main`，请把下面 URL 中的 `main` 换成你的实际分支名（如 `master`）。

---

## 🧭 典型使用流程（虚拟机安装 Debian 场景）

这是本工具最推荐的使用方式，特别适合在 VMware / VirtualBox / Hyper-V / PVE 里安装 Debian：

```
① Windows 宿主机
   └─ 下载并且在powershell里运行 Debian_Mirror_Test.ps1
       └─ 测速得到可用镜像列表
           └─ 安装器提示选择镜像源时，先填 ftp.cn.debian.org（官方调度，自动就近）

② Debian 安装完成，进入系统
   └─ 下载 debian_Mirror_Test.sh
       └─ sudo ./debian_Mirror_Test.sh
           └─ 选“2) 测速并自动设置最快的软件源”
               └─ 脚本自动备份、预检、写入最优源并 apt update
```

**为什么安装阶段建议先填 `ftp.cn.debian.org`？**

- 它是 Debian 官方调度入口，会按你的网络自动重定向到就近实体节点，**几乎不会踩坑**；
- 安装器阶段只需要“能装上”即可，不必追求极致速度；
- 真正的最优源留给系统装好后的 `.sh` 脚本去测、去换，那一步才有完整的 apt 预检和备份保障。

**Windows 版脚本的定位因此是“安装阶段的临时辅助”**：它不修改任何配置，只给你一个可用性/速度的参考榜单，让你在安装器那个小小的“Debian archive mirror”输入框里填得心里有数。

---

## ✨ 功能特性

### Debian Linux 版（`debian_Mirror_Test.sh`）

- ✅ 自动检测系统与 Debian 版本代号（codename），自动选择 `main contrib non-free non-free-firmware` 组件
- ✅ 自动区分 `buster/stretch`、`bullseye`、`bookworm/trixie/forky/sid` 的 security / updates 源路径差异
- ✅ **三层检测**：TCP 443 端口探测 → `InRelease` 元数据 HTTP 状态码校验 → 真实文件多轮下载测速
- ✅ 多轮测速取平均值，过滤被防刷策略拦截的“假高速”响应
- ✅ 自动按延迟排序，并用 **真实 `apt-get update` 引擎** 对候选源做落地预检（避免 403 / 证书错误）
- ✅ 一键备份原配置到 `/etc/apt/backup/`，再写入新源并执行 `apt update`
- ✅ 支持禁用 DVD/CDROM 本地源、查看当前源配置、仅测速不改系统、手动指定镜像
- ✅ 彩色终端输出，菜单式交互

### Windows 版（`Debian_Mirror_Test.ps1`）

- ✅ **无需 Linux 环境**，在 Windows 宿主机上即可对镜像站测速，适合虚拟机装 Debian 前使用
- ✅ 同样执行 TCP 端口探测 + `InRelease` 校验 + 多轮下载测速
- ✅ 输出按延迟排序的排行榜，并生成 **Debian 12+ 新格式（`debian.sources`）** 与 **传统 `sources.list` 格式** 两套推荐配置
- ✅ 自动处理 TLS 1.2/1.3、IPv4 强制、UA 伪装等细节
- ✅ **只测速、只输出，不改系统**，可放心在宿主机运行

---

## 📦 快速开始（下载脚本）

### 方式一：使用 `wget` 下载（推荐 Linux 使用）

```bash
# Linux 脚本（在装好 Debian 后下载）
wget -O debian_Mirror_Test.sh \
  https://raw.githubusercontent.com/HonKer-Dynamo/debian-mirror-speedtest/main/debian_Mirror_Test.sh

# Windows PowerShell 脚本（在安装debian的选择仓库源的时候可以测试速度有ISO自带的源测试）
wget -O Debian_Mirror_Test.ps1 \
  https://raw.githubusercontent.com/HonKer-Dynamo/debian-mirror-speedtest/main/Debian_Mirror_Test.ps1
```

### 方式二：使用 `curl` 下载

```bash
curl -fL -o debian_Mirror_Test.sh \
  https://raw.githubusercontent.com/HonKer-Dynamo/debian-mirror-speedtest/main/debian_Mirror_Test.sh

curl -fL -o Debian_Mirror_Test.ps1 \
  https://raw.githubusercontent.com/HonKer-Dynamo/debian-mirror-speedtest/main/Debian_Mirror_Test.ps1
```

### 方式三：在 Windows 上下载（虚拟机安装前使用）

Windows 10/11 自带 `curl.exe`，请在**PowerShell** 中执行（PowerShell 里务必写 `curl.exe`，不能只写 `curl`，否则会被解析为 `Invoke-WebRequest` 别名）：

```powershell
curl.exe -fL -O https://raw.githubusercontent.com/HonKer-Dynamo/debian-mirror-speedtest/main/Debian_Mirror_Test.ps1
```

或使用 PowerShell 原生命令：

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/HonKer-Dynamo/debian-mirror-speedtest/main/Debian_Mirror_Test.ps1" -OutFile "Debian_Mirror_Test.ps1"
```

> 💡 如果 `raw.githubusercontent.com` 访问缓慢，可自行使用代理或镜像加速服务，但请确认下载内容与仓库一致。

---

## 🐧 Linux 版使用教程（系统装好后精调）

### 1. 赋予执行权限

```bash
chmod +x debian_Mirror_Test.sh
```

### 2. 以 root 运行

脚本需要修改 `/etc/apt/sources.list`，必须使用 `sudo`：

```bash
sudo ./debian_Mirror_Test.sh
```

或直接：

```bash
sudo bash debian_Mirror_Test.sh
```

### 3. 依赖检查

脚本会自动检查：

- 是否为 root 权限
- 是否为 Debian 系发行版（读取 `/etc/os-release`）
- 是否已安装 `curl`（如缺失会提示 `apt install curl`）

### 4. 菜单说明

```
========================================================
         Debian 镜像源测速与配置工具 (全功能版)
========================================================
 1) 禁用本地 DVD/CDROM 源
 2) 测速并自动设置最快的软件源 (推荐)
 3) 仅测试镜像源速度 (不修改系统)
 4) 手动选择并设置软件源
 5) 查看当前软件源配置
 0) 退出脚本
========================================================
```

各选项行为：

| 选项 | 说明                                                         |
| ---- | ------------------------------------------------------------ |
| `1`  | 检查 `sources.list` 中 `deb cdrom:` 行并注释掉，同时备份为 `sources.list.bak` |
| `2`  | 完整流程：测速 → 排序 → 用临时 apt 配置预检 → 备份原配置 → 写入新 `sources.list` → `apt update` |
| `3`  | 只测速并输出排名，**不会修改任何系统文件**                   |
| `4`  | 列出所有镜像供手动选择，选定后直接应用并 `apt update`        |
| `5`  | 展示 `/etc/apt/sources.list` 与 `/etc/apt/sources.list.d/` 下所有有效源 |
| `0`  | 退出                                                         |

> 💡 从虚拟机安装完成后第一次进系统，建议先跑一次 **选项 1** 禁用 DVD 源（安装介质可能仍挂在 apt 里），再跑 **选项 2** 自动配置。

### 5. 自动配置流程（选项 2）细节

1. 对镜像列表逐个做 **TCP 443 端口探测**（1 秒超时），不通则跳过。
2. 请求 `https://<mirror>/debian/dists/<codename>/InRelease`，要求 HTTP 200；`403` 视为被防刷策略拦截，`000` 视为超时。
3. 对 `https://<mirror>/debian/ls-lR.gz` 进行 **3 轮下载测速**，过滤低于 10 KB/s 的无效结果后取平均。
4. 按平均延迟升序排名，展示排行榜。
5. 依次用候选镜像生成临时 apt 配置，执行真实 `apt-get update` 做预检，第一个通过者被选为最终镜像。
6. 备份原配置到 `/etc/apt/backup/`，写入经典 `sources.list` 格式，并执行 `apt update`。

### 6. 备份与恢复

脚本会把原配置备份到：

```
/etc/apt/backup/sources.list.bak
/etc/apt/backup/debian.sources.bak
```

需要恢复时：

```bash
sudo cp /etc/apt/backup/sources.list.bak /etc/apt/sources.list
sudo apt update
```

> ⚠️ 应用新源时脚本会 **删除** `/etc/apt/sources.list.d/debian.sources`，以避免新旧格式冲突。若你依赖该文件，请先手动备份。

### 7. 生成的源格式示例

```bash
========================================================
         Debian 镜像源测速与配置工具 (全功能版)
========================================================
 1) 禁用本地 DVD/CDROM 源
 2) 测速并自动设置最快的软件源 (推荐)
 3) 仅测试镜像源速度 (不修改系统)
 4) 手动选择并设置软件源
 5) 查看当前软件源配置
 0) 退出脚本
========================================================
请输入选项 [0-5]: 2
开始极速探测并测速 (适配版本: trixie)... 
[测试] deb.debian.org ...               -> 1104 ms | 13.98 MB/s
[测试] ftp.cn.debian.org ...            -> [跳过] 被防刷策略拦截 (403)
[测试] debian-archive.trafficmanager.net ...-> [跳过] 端口不通/宕机
[测试] mirrors.aliyun.com ...           -> 657 ms | 23.73 MB/s
[测试] mirrors.cloud.tencent.com ...    -> 897 ms | 20.29 MB/s
[测试] mirrors.huaweicloud.com ...      -> 1016 ms | 15.18 MB/s
[测试] mirrors.ctyun.cn ...             -> 1646 ms | 9.38 MB/s
[测试] mirrors.volces.com ...           -> 1644 ms | 9.38 MB/s
[测试] mirrors.163.com ...              -> [跳过] 连接超时 (000)
[测试] mirrors.tuna.tsinghua.edu.cn ... -> [跳过] 被防刷策略拦截 (403)
[测试] mirrors.pku.edu.cn ...           -> 1430 ms | 11.26 MB/s
[测试] mirrors.zju.edu.cn ...           -> 3000 ms | 35.44 KB/s
[测试] mirrors.ustc.edu.cn ...          -> 764 ms | 20.52 MB/s
[测试] mirror.nju.edu.cn ...            -> 1128 ms | 13.70 MB/s
[测试] mirrors.sjtug.sjtu.edu.cn ...    -> 1399 ms | 10.97 MB/s
[测试] mirrors.hust.edu.cn ...          -> [跳过] 端口不通/宕机
[测试] mirror.lzu.edu.cn ...            -> 1223 ms | 12.60 MB/s
[测试] mirrors.bfsu.edu.cn ...          -> [跳过] 被防刷策略拦截 (403)
[测试] mirrors.hit.edu.cn ...           -> 2576 ms | 4.84 MB/s
[测试] mirrors.neusoft.edu.cn ...       -> [跳过] 端口不通/宕机
[测试] mirror.nyist.edu.cn ...          -> 964 ms | 15.98 MB/s
[测试] mirrors.jlu.edu.cn ...           -> 1177 ms | 13.11 MB/s
[测试] mirror.iscas.ac.cn ...           -> 1408 ms | 12.59 MB/s
[测试] mirrors.cstcloud.cn ...          -> 3000 ms | 490.46 KB/s

==================== [ 测速结果排名 ] ====================
[最优选] ★ 延迟: 657 ms | 镜像: mirrors.aliyun.com
[第 2 名]   延迟: 764 ms | 镜像: mirrors.ustc.edu.cn
[第 3 名]   延迟: 897 ms | 镜像: mirrors.cloud.tencent.com
[第 4 名]   延迟: 964 ms | 镜像: mirror.nyist.edu.cn
[第 5 名]   延迟: 1016 ms | 镜像: mirrors.huaweicloud.com
[第 6 名]   延迟: 1104 ms | 镜像: deb.debian.org
[第 7 名]   延迟: 1128 ms | 镜像: mirror.nju.edu.cn
[第 8 名]   延迟: 1177 ms | 镜像: mirrors.jlu.edu.cn
[第 9 名]   延迟: 1223 ms | 镜像: mirror.lzu.edu.cn
[第 10 名]   延迟: 1399 ms | 镜像: mirrors.sjtug.sjtu.edu.cn
[第 11 名]   延迟: 1408 ms | 镜像: mirror.iscas.ac.cn
[第 12 名]   延迟: 1430 ms | 镜像: mirrors.pku.edu.cn
[第 13 名]   延迟: 1644 ms | 镜像: mirrors.volces.com
[第 14 名]   延迟: 1646 ms | 镜像: mirrors.ctyun.cn
[第 15 名]   延迟: 2576 ms | 镜像: mirrors.hit.edu.cn
[第 16 名]   延迟: 3000 ms | 镜像: mirrors.cstcloud.cn
[第 17 名]   延迟: 3000 ms | 镜像: mirrors.zju.edu.cn
========================================================

正在使用真实 apt 引擎预检: mirrors.aliyun.com ...
  ✔ 预检通过！apt 可以正常访问此源。
准备将系统源更换为: https://mirrors.aliyun.com/debian/
✔ 已将原配置备份至 /etc/apt/backup
✔ 软件源已成功更新！
正在执行 apt update...
Hit:1 https://mirrors.aliyun.com/debian trixie InRelease
Hit:2 https://mirrors.aliyun.com/debian-security trixie-security InRelease
Hit:3 https://mirrors.aliyun.com/debian trixie-updates InRelease
Hit:4 https://mirrors.huaweicloud.com/docker-ce/linux/debian trixie InRelease
All packages are up to date.                            

按回车键返回主菜单...
```



---

## 🪟 Windows 版使用教程（虚拟机安装 Debian 时的临时源选择）

Windows 版脚本 **只测速并输出推荐配置，不会修改任何系统设置**。它的主要用途是：在虚拟机里安装 Debian 的过程中，安装器会要求你填写 `Debian archive mirror` 地址，此时用它快速判断哪个源可用、哪个快。

### 1. 下载脚本

见上文“快速开始 → 方式三”。

### 2. 运行脚本

右键“使用 PowerShell 运行”，或在 PowerShell 中执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Debian_Mirror_Test.ps1
```

如果提示执行策略限制，也可以先临时放开：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Debian_Mirror_Test.ps1
```

### 3. 输入 Debian 版本代号

脚本会提示：

```
请输入你当前的 Debian 版本代号 (如 buster, bullseye, bookworm, trixie) [默认: trixie]
```

直接回车使用默认值 `trixie`。**请确保输入的代号与你准备安装的 Debian 版本一致**，否则 `InRelease` 校验会失败（例如安装 Debian 12 就填 `bookworm`）。

### 4. 在安装器里填写源

拿到测速结果后，回到虚拟机里的 Debian 安装器：

- 在“配置软件包管理器 / 选择 Debian 镜像”界面，**首选填入官方调度源**：

  ```
  ftp.cn.debian.org
  ```

  它是官方调度入口，会自动就近重定向，安装阶段最稳妥。
- 如果你所在网络对 `ftp.cn.debian.org` 不友好（脚本里显示超时/403），再按排行榜里的结果填其他镜像域名（如 `mirrors.aliyun.com`、`mirrors.tuna.tsinghua.edu.cn` 等）。

> 安装器阶段通常只要求填主机名，不需要写 `/debian/` 路径，也不区分 http/https；具体以安装界面提示为准。安装阶段只求“装得上”，不必纠结极致速度。

### 5. 装好系统后，改用 `.sh` 脚本精调

Debian 安装完成、进入系统后，回到本仓库下载 Linux 脚本：

```bash
wget -O debian_Mirror_Test.sh \
  https://raw.githubusercontent.com/HonKer-Dynamo/debian-mirror-speedtest/main/debian_Mirror_Test.sh
chmod +x debian_Mirror_Test.sh
sudo ./debian_Mirror_Test.sh
```

选择 **`2) 测速并自动设置最快的软件源`**，脚本会完成测速、apt 预检、备份和写入新源，把安装阶段临时选的源替换成当前网络下真正最优的那一个。这才是长期使用的最终配置。

### 6. 输出示例

脚本会输出：

- 每个镜像的测试状态（跳过原因 / 延迟 / 速度）
- 按延迟排序的排行榜
- **方案 A**：Debian 12+ 新格式 `debian.sources` 配置
- **方案 B**：传统 `sources.list` 配置

方案 A/B 主要供你参考或手动粘贴使用；虚拟机场景下，安装阶段的镜像选择 + 装好后的 `.sh` 自动配置已经覆盖了绝大多数需求。
```powershell
⚡HonKer ❯❯ .\Debian_Mirror_Test.ps1
========================================================
      Debian 镜像站 HTTP 延迟与有效性测速 (Windows)
========================================================
请输入你当前的 Debian 版本代号 (如 buster, bullseye, bookworm, trixie) [默认: trixie]:

当前测试版本: trixie

[deb.debian.org                          ] -> 1494 ms | 14.52 MB/s
[ftp.cn.debian.org                       ] -> [跳过] 连接超时 (HTTP 000)
[debian-archive.trafficmanager.net       ] -> [跳过] 端口不通/宕机
[mirrors.163.com                         ] -> 3012 ms | 491.99 KB/s
[mirrors.ustc.edu.cn                     ] -> 937 ms | 17.16 MB/s
[mirror.lzu.edu.cn                       ] -> 2421 ms | 5.81 MB/s
[mirrors.bfsu.edu.cn                     ] -> [跳过] 触发防刷策略 (HTTP 403)
[mirror.nju.edu.cn                       ] -> 2355 ms | 7.54 MB/s
[mirrors.hit.edu.cn                      ] -> 2922 ms | 4.21 MB/s
[mirrors.neusoft.edu.cn                  ] -> [跳过] 端口不通/宕机
[mirror.nyist.edu.cn                     ] -> 1059 ms | 14.57 MB/s
[mirrors.jlu.edu.cn                      ] -> 1765 ms | 9.13 MB/s
[mirrors.tuna.tsinghua.edu.cn            ] -> [跳过] 触发防刷策略 (HTTP 403)
[mirrors.aliyun.com                      ] -> 2122 ms | 7.38 MB/s
[mirrors.cloud.tencent.com               ] -> 836 ms | 20.84 MB/s
[mirrors.huaweicloud.com                 ] -> 1401 ms | 12.07 MB/s
[mirrors.ctyun.cn                        ] -> 1629 ms | 9.51 MB/s
[mirrors.volces.com                      ] -> 1447 ms | 10.72 MB/s
[mirrors.pku.edu.cn                      ] -> 1680 ms | 11.78 MB/s
[mirrors.zju.edu.cn                      ] -> [跳过] 端口不通/宕机
[mirrors.sjtug.sjtu.edu.cn               ] -> 1749 ms | 8.89 MB/s
[mirrors.hust.edu.cn                     ] -> 3010 ms | 437.72 KB/s
[mirror.iscas.ac.cn                      ] -> 1698 ms | 10.42 MB/s
[mirrors.cstcloud.cn                     ] -> 3005 ms | 369.24 KB/s

========================================================
                      [ 测速结果排名 ]
========================================================
[最优选] ★ 延迟: 836 ms | 速度: 20.84 MB/s | 镜像: mirrors.cloud.tencent.com
[第 2  名] 延迟: 937 ms | 速度: 17.16 MB/s | 镜像: mirrors.ustc.edu.cn
[第 3  名] 延迟: 1059 ms | 速度: 14.57 MB/s | 镜像: mirror.nyist.edu.cn
[第 4  名] 延迟: 1401 ms | 速度: 12.07 MB/s | 镜像: mirrors.huaweicloud.com
[第 5  名] 延迟: 1447 ms | 速度: 10.72 MB/s | 镜像: mirrors.volces.com
[第 6  名] 延迟: 1494 ms | 速度: 14.52 MB/s | 镜像: deb.debian.org
[第 7  名] 延迟: 1629 ms | 速度: 9.51 MB/s | 镜像: mirrors.ctyun.cn
[第 8  名] 延迟: 1680 ms | 速度: 11.78 MB/s | 镜像: mirrors.pku.edu.cn
[第 9  名] 延迟: 1698 ms | 速度: 10.42 MB/s | 镜像: mirror.iscas.ac.cn
[第 10 名] 延迟: 1749 ms | 速度: 8.89 MB/s | 镜像: mirrors.sjtug.sjtu.edu.cn
[第 11 名] 延迟: 1765 ms | 速度: 9.13 MB/s | 镜像: mirrors.jlu.edu.cn
[第 12 名] 延迟: 2122 ms | 速度: 7.38 MB/s | 镜像: mirrors.aliyun.com
[第 13 名] 延迟: 2355 ms | 速度: 7.54 MB/s | 镜像: mirror.nju.edu.cn
[第 14 名] 延迟: 2421 ms | 速度: 5.81 MB/s | 镜像: mirror.lzu.edu.cn
[第 15 名] 延迟: 2922 ms | 速度: 4.21 MB/s | 镜像: mirrors.hit.edu.cn
[第 16 名] 延迟: 3005 ms | 速度: 369.24 KB/s | 镜像: mirrors.cstcloud.cn
[第 17 名] 延迟: 3010 ms | 速度: 437.72 KB/s | 镜像: mirrors.hust.edu.cn
[第 18 名] 延迟: 3012 ms | 速度: 491.99 KB/s | 镜像: mirrors.163.com

========================================================
               [ 推荐配置 (复制到 Linux 执行) ]
========================================================

>>> 方案 A: 官方推荐的新格式 (适用于 Debian 12+，放入 /etc/apt/sources.list.d/debian.sources)
Types: deb
URIs: https://mirrors.cloud.tencent.com/debian/
Suites: trixie
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://mirrors.cloud.tencent.com/debian-security/
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

>>> 方案 B: 传统 sources.list 格式 (适用于所有版本，放入 /etc/apt/sources.list)
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://mirrors.cloud.tencent.com/debian/ trixie main contrib non-free non-free-firmware
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://mirrors.cloud.tencent.com/debian-security/ trixie-security main contrib non-free non-free-firmware
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://mirrors.cloud.tencent.com/debian/ trixie-updates main contrib non-free non-free-firmware
========================================================
```



### 7. 依赖说明

- Windows 10 1803+ / Windows 11 自带 `curl.exe`
- 若提示找不到 `curl.exe`，请安装 curl
- 脚本使用 `curl.exe` 而非 PowerShell 别名 `curl`（后者实际是 `Invoke-WebRequest`）

---

## 🔬 测速原理

| 阶段 | 检测内容                     | 超时          | 说明                                        |
| ---- | ---------------------------- | ------------- | ------------------------------------------- |
| 1    | TCP 443 连通性               | 1 s           | 快速排除宕机 / 被墙节点                     |
| 2    | `dists/<codename>/InRelease` | 3 s           | 校验 HTTP 200，排除 403 防刷与无效元数据    |
| 3    | `/debian/ls-lR.gz` 下载      | 3 s/轮 × 3 轮 | 取平均速度与平均耗时，低于 10 KB/s 视为无效 |

- 强制 **IPv4**（`-4`），减少双栈环境下的抖动
- 伪装 Debian APT 的 User-Agent：`Debian APT-HTTP/1.3 (2.7.14)`
- 忽略证书错误（`-k`），避免个别镜像证书链问题导致误判
- 跟随重定向（`-L`），兼容官方调度源 `deb.debian.org`、`ftp.cn.debian.org`

---

## 🌐 内置镜像列表

脚本内置以下镜像（Linux 与 Windows 版本略有差异，以脚本内实际数组为准）：

**官方调度入口**

- `deb.debian.org`
- `ftp.cn.debian.org`
- `debian-archive.trafficmanager.net`

**云厂商**

- `mirrors.aliyun.com`（阿里云）
- `mirrors.cloud.tencent.com`（腾讯云）
- `mirrors.huaweicloud.com`（华为云）
- `mirrors.ctyun.cn`（天翼云）
- `mirrors.volces.com`（火山引擎）
- `mirrors.163.com`（网易）

**高校 / 科研机构**

- `mirrors.tuna.tsinghua.edu.cn`（清华 TUNA）
- `mirrors.pku.edu.cn`（北大）
- `mirrors.zju.edu.cn`（浙大）
- `mirrors.ustc.edu.cn`（中科大）
- `mirror.nju.edu.cn`（南大）
- `mirrors.sjtug.sjtu.edu.cn`（上交）
- `mirrors.hust.edu.cn`（华科）
- `mirror.lzu.edu.cn`（兰大）
- `mirrors.bfsu.edu.cn`（北外）
- `mirrors.hit.edu.cn`（哈工大）
- `mirrors.neusoft.edu.cn`（东软）
- `mirror.nyist.edu.cn`（南阳理工）
- `mirrors.jlu.edu.cn`（吉大）
- `mirror.iscas.ac.cn`（中科院软件所）
- `mirrors.cstcloud.cn`（中国科技云）

如需增删镜像，直接编辑脚本顶部的 `mirrors` 数组（Bash）或 `$Mirrors`（PowerShell）即可。

---

## ⚠️ 注意事项

1. **请用 `wget` / `curl` 下载单个文件，而不是 `git clone`**。本仓库没有需要编译或安装的工程结构，克隆只会多下载无关内容。
2. **虚拟机安装阶段**：安装器里选择镜像时，**优先填 `ftp.cn.debian.org`**（官方调度，自动就近）。Windows 版脚本的作用是帮你判断是否需要用其他源临时替代，而不是安装阶段的最终答案。
3. **装好系统后**：请务必再下载 `.sh` 脚本跑一次自动配置，把安装阶段的临时源替换成当前网络下的最优源。
4. **Linux 脚本必须以 root 运行**，且会修改 `/etc/apt/sources.list`。执行前请确认你了解风险。
5. 脚本会自动备份原配置到 `/etc/apt/backup/`，但**建议你在运行前自行再备份一次**：
   ```bash
   sudo cp -a /etc/apt/sources.list /etc/apt/sources.list.bak.manual
   sudo cp -a /etc/apt/sources.list.d /etc/apt/sources.list.d.bak.manual
   ```
6. 应用新源时会 **删除 `/etc/apt/sources.list.d/debian.sources`**，如果你在 Debian 12+ 上使用新格式源，请注意这一点。
7. 测速结果受你当前网络、运营商、时段影响，**不代表长期最优**；建议隔段时间重新测速。
8. 某些镜像对 `ls-lR.gz` 做了限流或返回 403，这并不代表该镜像不可用，脚本会将其判为“跳过”，也不影响安装阶段直接用该镜像域名。
9. Windows 版脚本**不会修改系统配置**，只做测速与配置输出，可放心在宿主机运行。
10. 脚本会创建临时文件 `/tmp/debian_mirror_test.tmp`、`/tmp/apt_test_*`，运行结束后自动清理。

---

## ❓ 常见问题（FAQ）

**Q1：提示 `curl: command not found`？**

```bash
sudo apt update && sudo apt install -y curl
```

**Q2：提示“请使用 sudo 运行此脚本”？**

脚本需要写 `/etc/apt/sources.list`，必须以 root 执行：`sudo ./debian_Mirror_Test.sh`。

**Q3：虚拟机安装 Debian 时，安装器里的镜像该填什么？**

先填官方调度源 `ftp.cn.debian.org`（最稳妥，自动就近）。如果 Windows 版脚本显示它在你的网络下异常，再按测速排行榜填其他域名。安装阶段只求装得上，装好后再用 `.sh` 脚本精调。

**Q4：安装器里填镜像需要带 `http://` 或 `/debian/` 路径吗？**

一般只需要填主机名（如 `ftp.cn.debian.org`），具体以安装界面提示为准。安装器的镜像输入框和 `sources.list` 写法不同，不要直接把完整 `deb` 行粘进去。

**Q5：测速全部失败 / 全部被跳过？**

- 检查本机网络与 DNS
- 检查是否处于公司/校园网限制环境
- 确认系统时间正确（TLS 证书校验依赖时间）
- 可在 Linux 版选项 4 中手动选择镜像并强制应用

**Q6：为什么有些镜像显示“被防刷策略拦截 (403)”？**

部分镜像对非浏览器/高频请求返回 403，或对 `ls-lR.gz` 做了限制。这属于镜像侧策略，不是脚本问题。

**Q7：更换源后 `apt update` 报错怎么办？**

恢复备份：

```bash
sudo cp /etc/apt/backup/sources.list.bak /etc/apt/sources.list
sudo apt update
```

**Q8：Debian 12+ 用新格式还是旧格式？**

两种都可以。脚本默认写入传统 `sources.list` 格式（兼容性最好、用户最熟悉）；Windows 版会同时给出新格式 `debian.sources` 供选择。

**Q9：PowerShell 提示“无法加载文件，因为在此系统上禁止运行脚本”？**

```powershell
powershell -ExecutionPolicy Bypass -File .\Debian_Mirror_Test.ps1
```

**Q10：能在 Ubuntu / Kali / 树莓派系统上用吗？**

脚本会检测 `ID` 或 `ID_LIKE` 是否包含 `debian`，Debian 衍生版理论上可用，但源路径与组件可能需要自行调整，请谨慎使用。

---

## 🤝 贡献

欢迎提交 Issue 或 Pull Request：

- 新增 / 修正镜像地址
- 适配新的 Debian 版本代号
- 改进测速逻辑与错误处理
- 补充文档与使用示例

提交前请尽量在本地测试脚本可正常运行。

---

## 📄 免责声明

本脚本会修改系统 APT 源配置文件。尽管内置了自动备份与预检机制，仍建议你在运行前自行备份重要配置。使用本脚本所产生的一切后果由使用者自行承担，作者不对因使用本脚本导致的系统异常、软件源不可用或数据损失负责。

---

## 📜 License

本项目基于 [MIT License](LICENSE) 开源。

Copyright (c) 2026 HonKer-Dynamo

---

> 如果这个项目对你有帮助，欢迎点一个 ⭐ Star！
> 仓库地址：<https://github.com/HonKer-Dynamo/debian-mirror-speedtest>