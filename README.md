# hbasstuNet for OpenWrt

面向湖北文理学院理工学院校园网的 OpenWrt LuCI 自动认证插件，在路由器后台检查连接状态并完成 Portal 登录。

![OpenWrt](https://img.shields.io/badge/OpenWrt-24.10-00B5E2?style=flat-square&logo=openwrt) ![LuCI](https://img.shields.io/badge/LuCI-Application-00B5E2?style=flat-square) ![Shell](https://img.shields.io/badge/Shell-POSIX-4EAA25?style=flat-square&logo=gnubash)

> [!WARNING]
> 本项目仅用于学习、研究和个人合法网络接入。请遵守学校网络管理规定，不得用于绕过认证、共享账号、干扰网络或其他未授权行为，详情请见[免责声明](./DISCLAIMER.md)

## ✨ 功能特性

- 提供 LuCI 中文配置页面
- 支持学生/教师账号类型选择
- 使用 LuCI 原生下拉菜单选择 OpenWrt 逻辑网络
- 自动获取所选网络的 IPv4 地址、设备名和 MAC 地址
- 自动完成 CSRF Token、Cookie、登录、状态检查和登出流程
- 认证失效后自动重新登录
- 由 procd 管理后台服务并支持异常拉起
- 账号配置保存在独立 UCI 配置文件中

> [!NOTE]
> “校园网接口”应选择实际连接校园网的 OpenWrt 逻辑网络，通常是 `wan`；无线中继或自定义网络也可能叫 `wwan` 或其他名称。插件会使用该网络的地址和 MAC 进行认证，不应选择只服务于内网设备的 `lan`。

## 📦 安装

### 方式一：安装 IPK

将构建好的 `.ipk` 上传到 OpenWrt 后安装：

```sh
opkg install luci-app-hbasstunet_*.ipk
```

安装后进入 LuCI 的“网络 → hbasstuNet”。如果菜单没有立即出现，可注销并重新登录 LuCI，或清理 LuCI 缓存后再试。

### 方式二：使用 OpenWrt SDK 构建

将本项目复制到 OpenWrt SDK 的 `package/luci-app-hbasstunet/`，然后执行：

```sh
./scripts/feeds update -a
./scripts/feeds install -a
make defconfig
make package/luci-app-hbasstunet/compile V=s
```

生成的安装包位于 SDK 的 `bin/packages/` 目录。仓库内的 `build.sh` 和 `build.bat` 也提供了基于容器构建 OpenWrt 24.10 软件包的流程。

## 🚀 使用方法

1. 打开 LuCI 的“网络 → hbasstuNet”
2. 填写校园网账号和密码
3. 选择学生或教师账号类型
4. 从下拉菜单选择连接校园网的逻辑网络
5. 按需确认门户地址和 NAS ID
6. 勾选“启用自动登录”并保存应用

默认门户地址为 `http://192.168.99.135`，默认逻辑网络为 `wan`。

## 🔌 校园网接口有什么用？

OpenWrt 可能同时存在 `lan`、`wan`、`wwan` 等多个逻辑网络。插件需要知道哪一个网络连接到了校园网，以便：

1. 通过 ubus 查询该网络当前使用的三层设备
2. 读取校园网分配的 IPv4 地址和设备 MAC 地址
3. 将 Portal 请求绑定到该 IPv4 地址发送
4. 在地址尚未获取时等待，而不是使用错误的出口反复认证

这个选项填写的是 OpenWrt 的**逻辑网络名**，不是 `eth0`、`wlan0` 之类的 Linux 设备名。配置页使用 LuCI 的 `NetworkSelect` 控件读取系统中已有的逻辑网络，因此无需手工输入。

## 🧱 技术栈与架构

| 层级 | 技术 | 用途 |
| --- | --- | --- |
| 配置界面 | LuCI CBI | 账号、接口和 Portal 参数配置 |
| 配置存储 | UCI | 保存 `/etc/config/hbasstunet` |
| 服务管理 | procd | 启停、重载和异常拉起 |
| 认证核心 | POSIX Shell + curl | Portal 请求与会话维护 |
| 网络信息 | ubus + jsonfilter | 获取逻辑网络状态、IPv4 和设备名 |

```text
LuCI 配置页
└── UCI /etc/config/hbasstunet
    └── procd 后台服务
        ├── ubus 获取接口、IPv4 和 MAC
        ├── curl 调用 Portal API
        └── Cookie 与会话状态维护
```

## 📁 目录结构

```text
.
├── Makefile                              # OpenWrt 软件包定义
├── build.sh                              # 容器内 SDK 构建脚本
├── build.bat                             # Windows 构建入口
├── root/etc/config/hbasstunet            # 默认 UCI 配置
├── root/etc/init.d/hbasstunet            # procd 服务脚本
├── root/usr/sbin/hbasstunet              # 自动认证后台程序
├── root/usr/lib/lua/luci/controller/      # LuCI 菜单入口
└── root/usr/lib/lua/luci/model/cbi/       # LuCI 配置表单
```

## 🔍 运行状态与排查

```sh
/etc/init.d/hbasstunet status
logread -e hbasstunet
ubus call network.interface.wan status
```

如果选择的不是 `wan`，请将最后一条命令中的网络名替换为实际选择值。若日志持续显示“等待所选校园网接口获取 IPv4 地址”，通常表示所选逻辑网络尚未获得 IPv4 地址，或选错了网络。

## 🔐 配置与安全

账号和密码存储在 `/etc/config/hbasstunet`，服务启动时会尝试将该文件权限收紧为 `600`。

## 📄 说明

项目名称、校园网络名称及相关标识不代表学校官方背书；使用本软件还须遵守所在网络的管理规定。

## LICENSE
[MIT](./LICENSE)