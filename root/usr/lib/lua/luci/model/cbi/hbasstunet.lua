local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

m = Map("hbasstunet", translate("hbasstuNet"), translate("可为不同校园网接口分别添加认证账户。每个启用的账户由独立后台实例维护。"))
m.on_after_commit = function() sys.call("/etc/init.d/hbasstunet reload >/dev/null 2>&1") end

s = m:section(TypedSection, "hbasstunet", translate("认证账户"))
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "hbasstunet/tsection"

e = s:option(Flag, "enabled", translate("启用"))
e.default = "0"
e.rmempty = false
e.description = translate("每个启用的账户都会启动一个独立认证实例。")

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

i = s:option(ListValue, "interface", translate("校园网接口"))
i.default = "wan"
i.rmempty = false
i.description = translate("选择该账户专用的 OpenWrt 逻辑网络；插件会绑定其源 IPv4，并让认证请求使用该接口对应的路由表。")
uci:foreach("network", "interface", function(iface)
    local name = iface[".name"]
    if name and name ~= "loopback" then
        i:value(name, iface.description or name)
    end
end)

function i.validate(self, value, section)
    if not value or value == "" then
        return nil, translate("请选择校园网接口")
    end
    local duplicate = false
    uci:foreach("hbasstunet", "hbasstunet", function(account)
        if account[".name"] ~= section and account.enabled == "1" and account.interface == value then
            duplicate = true
        end
    end)
    if duplicate then
        return nil, translate("一个接口只能绑定一个启用的认证账户")
    end
    return value
end

b = s:option(Value, "portal_url", translate("门户地址"))
b.default = "http://192.168.99.135"
b.rmempty = false

n = s:option(Value, "nas_id", translate("NAS ID"))
n.default = "1"
n.rmempty = false

u = m:section(SimpleSection, translate("软件更新"))
u.template = "hbasstunet/update"

return m
