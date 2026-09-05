# 单 IPK 多账户架构

luci-app-hbasstunet 使用一个 IPK、一个 UCI 配置文件、一个认证程序和一个 procd 服务管理多个校园网账户。

## 配置和进程模型

LuCI 可新增、删除和排序 hbasstunet 类型的 UCI section。每个 section 保存 enabled、username、password、role、interface、portal_url 和 nas_id。procd 为每个启用的 section 启动一个命名进程，命令是 /usr/sbin/hbasstunet 加 section 名。

旧版本的 main section 仍属于相同类型，升级后会继续被枚举；新安装默认创建 account1。配置文件是 conffile，升级不会覆盖已有账户。

## 会话隔离

每个实例使用 /var/run/hbasstunet/<section>/，分别保存 Cookie、CSRF、ISP、SessionId 和状态。日志标签为 hbasstunet.<section>，因此一个账户失败不会覆盖另一账户的文件或日志上下文。

## 网络身份隔离

实例通过 ubus 将逻辑接口动态解析为实际 l3_device、IPv4、MAC 和网关，再用 curl --interface <IPv4> 固定 Portal 请求的源地址。仅绑定源地址并不能决定本机流量的出口，因此实例还会添加一条 `from <IPv4>/32` 源策略规则：优先复用该接口已有的 mwan3 路由表；没有现成表时建立实例私有路由表。规则优先级位于 mwan3 默认 fwmark 规则之前，接口或地址变化时重建，进程退出时只清理本实例创建的规则和私有表。

两条 WAN 共用网段和网关时，curl 绑定物理设备可能因内核邻居/路由状态返回 ENETUNREACH；“源 IPv4 绑定 + 源策略路由”能同时固定请求身份和实际出口。服务端响应仍必须匹配当前 IPv4/MAC，运行时 MAC 锁防止不同逻辑接口落到同一设备身份。

登录和状态响应必须匹配配置账号、当前 IPv4、当前 MAC，并包含 SessionId。任一字段不匹配即视为串会话，只清除该实例的本地状态，不调用服务端登出，以免把另一账户踢下线。

## mwan3 边界

认证程序不修改 UCI network、firewall 或 mwan3 配置，只在运行期维护认证所需的源策略规则。两条 WAN 分别认证成功后，再由 mwan3 对普通业务连接做负载均衡和故障切换。
