# 单 IPK 多账户架构

luci-app-hbasstunet 使用一个 IPK、一个 UCI 配置文件、一个认证程序和一个 procd 服务管理多个校园网账户。

## 配置和进程模型

LuCI 可新增、删除和排序 hbasstunet 类型的 UCI section。每个 section 保存 enabled、username、password、role、interface、portal_url 和 nas_id。procd 为每个启用的 section 启动一个命名进程，命令是 /usr/sbin/hbasstunet 加 section 名。

旧版本的 main section 仍属于相同类型，升级后会继续被枚举；新安装默认创建 account1。配置文件是 conffile，升级不会覆盖已有账户。

## 会话隔离

每个实例使用 /var/run/hbasstunet/<section>/，分别保存 Cookie、CSRF、ISP、SessionId 和状态。日志标签为 hbasstunet.<section>，因此一个账户失败不会覆盖另一账户的文件或日志上下文。

## 网络身份隔离

实例通过 ubus 将逻辑接口解析为实际 l3_device、IPv4 和 MAC，再用 curl --interface <IPv4> 固定 Portal 请求的源地址。设备名仍用于确认链路状态，MAC 用于身份校验和运行时身份锁。保护分三层：LuCI 阻止重复逻辑接口；procd 启动脚本复查 UCI；运行时按真实 MAC 加身份锁，防止不同逻辑接口落到同一设备身份。

登录和状态响应必须匹配配置账号、当前 IPv4、当前 MAC，并包含 SessionId。任一字段不匹配即视为串会话，只清除该实例的本地状态，不调用服务端登出，以免把另一账户踢下线。

## mwan3 边界

认证程序只固定自身 Portal 流量，不修改 network、firewall 或 mwan3。两条 WAN 分别认证成功后，再由 mwan3 对普通业务连接做负载均衡和故障切换。
