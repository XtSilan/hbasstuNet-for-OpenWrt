local sys = require "luci.sys"
local widgets = require "luci.tools.widgets"

m = Map("hbasstunet", translate("hbasstuNet"), translate("校园网自动登录设置"))
m.on_after_commit = function() sys.call("/etc/init.d/hbasstunet reload >/dev/null 2>&1") end

s = m:section(NamedSection, "main", "hbasstunet", translate("认证设置"))
s.anonymous = true

e = s:option(Flag, "enabled", translate("启用自动登录"))
e.default = "0"
e.rmempty = false
e.description = translate("启用后后台自动检查网络并使用保存的账号认证；关闭后停止认证并注销当前会话。")

u = s:option(Value, "username", translate("校园网账号"))
u.rmempty = false

p = s:option(Value, "password", translate("校园网密码"))
p.password = true
p.rmempty = false

r = s:option(ListValue, "role", translate("账号类型"))
r:value("student", translate("学生"))
r:value("teacher", translate("教师"))
r.default = "student"
r.rmempty = false

i = s:option(widgets.NetworkSelect, "interface", translate("校园网接口"))
i.default = "wan"
i.rmempty = false
i.nocreate = true
i.description = translate("选择连接校园网的 OpenWrt 逻辑网络（如 wan 或 wwan）；程序将使用该网络的 IPv4 地址和 MAC 地址进行门户认证。")

b = s:option(Value, "portal_url", translate("门户地址"))
b.default = "http://192.168.99.135"
b.rmempty = false

n = s:option(Value, "nas_id", translate("NAS ID"))
n.default = "1"
n.rmempty = false

return m
