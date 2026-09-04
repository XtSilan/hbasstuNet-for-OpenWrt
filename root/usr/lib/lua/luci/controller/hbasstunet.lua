module("luci.controller.hbasstunet", package.seeall)

local http = require "luci.http"
local util = require "luci.util"
local jsonc = require "luci.jsonc"
local dispatcher = require "luci.dispatcher"

local RELEASE_API = "https://api.github.com/repos/XtSilan/hbasstuNet-for-OpenWrt/releases/latest"

local function shellquote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function load_release()
    local raw = util.exec("curl -fsSL --retry 2 --connect-timeout 8 --max-time 20 -H 'Accept: application/vnd.github+json' -H 'User-Agent: hbasstunet-luci' " .. shellquote(RELEASE_API))
    if not raw or raw == "" then
        return nil, "无法连接 GitHub Release 服务"
    end

    local ok, data = pcall(jsonc.parse, raw)
    if not ok or type(data) ~= "table" or not data.tag_name then
        return nil, "GitHub 返回的 Release 数据无效"
    end

    local asset
    for _, candidate in ipairs(data.assets or {}) do
        if candidate.name and candidate.name:match("^luci%-app%-hbasstunet_.*%.ipk$") then
            asset = candidate
            break
        end
    end
    if not asset or not asset.browser_download_url then
        return nil, "最新 Release 没有可用的 OpenWrt IPK"
    end

    local current = util.exec("opkg status luci-app-hbasstunet 2>/dev/null | sed -n 's/^Version: //p' | head -n 1")
    current = (current or ""):match("^%s*(.-)%s*$")
    local current_version = current:gsub("%-.*$", "")
    local latest_version = tostring(data.tag_name):gsub("^v", "")

    return {
        tag_name = data.tag_name,
        body = data.body or "",
        html_url = data.html_url or "",
        published_at = data.published_at or "",
        asset_name = asset.name,
        asset_url = asset.browser_download_url,
        digest = asset.digest or "",
        current_version = current_version,
        update_available = current_version == "" or current_version ~= latest_version
    }
end

function update()
    local action = http.formvalue("action") or "check"
    local result = { ok = false }

    if action == "check" then
        local release, err = load_release()
        if release then
            result = release
            result.ok = true
        else
            result.message = err
        end
    elseif action == "install" then
        if http.getenv("REQUEST_METHOD") ~= "POST"
            or http.formvalue("token") ~= dispatcher.context.authtoken
            or http.formvalue("confirm") ~= "1" then
            result.message = "安装请求无效"
        else
            local release, err = load_release()
            if not release then
                result.message = err
            else
                local expected = tostring(release.digest):match("^sha256:(%x+)$")
                if not expected or #expected ~= 64 then
                    result.message = "Release 未提供有效的 SHA-256，已取消安装"
                else
                    local tmp = "/tmp/luci-app-hbasstunet-update.ipk"
                    local download = "curl -fL --retry 2 --connect-timeout 10 --max-time 120 -o " .. shellquote(tmp) .. " " .. shellquote(release.asset_url)
                    local status = os.execute(download)
                    if status ~= 0 then
                        result.message = "下载 IPK 失败"
                    else
                        local actual = util.exec("sha256sum " .. shellquote(tmp) .. " 2>/dev/null | awk '{print $1}'")
                        actual = (actual or ""):match("^%s*(%x+)") or ""
                        if actual ~= expected then
                            result.message = "IPK 校验失败，已取消安装"
                        else
                            local log_file = "/tmp/hbasstunet-opkg.log"
                            status = os.execute("opkg install --force-reinstall " .. shellquote(tmp) .. " >" .. shellquote(log_file) .. " 2>&1")
                            if status == 0 then
                                result.ok = true
                                result.tag_name = release.tag_name
                                result.message = "已安装 " .. release.tag_name
                            else
                                result.message = "opkg 安装失败：" .. (util.exec("cat " .. shellquote(log_file)) or "")
                            end
                        end
                        os.remove(tmp)
                    end
                end
            end
        end
    else
        result.message = "不支持的更新操作"
    end

    http.prepare_content("application/json")
    http.write_json(result)
end

function index()
    entry({"admin", "network", "hbasstunet"}, cbi("hbasstunet"), _("hbasstuNet"), 60).dependent = false
    local page = entry({"admin", "network", "hbasstunet", "update"}, call("update"))
    page.leaf = true
    page.dependent = true
end
