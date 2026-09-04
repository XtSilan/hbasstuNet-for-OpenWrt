module("luci.controller.hbasstunet", package.seeall)

function index()
    entry({"admin", "network", "hbasstunet"}, cbi("hbasstunet"), _("hbasstuNet"), 60).dependent = false
end
