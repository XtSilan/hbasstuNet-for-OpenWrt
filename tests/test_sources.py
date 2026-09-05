from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SourceContractTests(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_default_config_has_all_per_account_fields(self):
        config = self.read("root/etc/config/hbasstunet")
        self.assertIn("config hbasstunet 'account1'", config)
        for field in ("enabled", "username", "password", "role", "interface", "portal_url", "nas_id"):
            self.assertIn("option " + field, config)

    def test_service_starts_named_instance_for_every_section(self):
        init = self.read("root/etc/init.d/hbasstunet")
        self.assertIn("config_foreach start_instance hbasstunet", init)
        self.assertIn('procd_open_instance "$section"', init)
        self.assertIn('/usr/sbin/hbasstunet "$section"', init)
        self.assertIn("started_interfaces", init)

    def test_backend_is_per_section_and_device_bound(self):
        backend = self.read("root/usr/sbin/hbasstunet")
        self.assertNotIn("hbasstunet.main.", backend)
        self.assertIn('BASE="/var/run/hbasstunet/$SECTION"', backend)
        self.assertIn('curl -sS --interface "$IP"', backend)
        self.assertIn("claim_identity", backend)
        self.assertIn("SessionId", backend)
        for identity in ("Username", "UserIpv4", "UserMac"):
            self.assertIn(identity, backend)
        self.assertIn("response_message", backend)
        self.assertIn('reset_local error "$msg"', backend)

    def test_backend_installs_source_policy_route_and_cleans_it(self):
        backend = self.read("root/usr/sbin/hbasstunet")
        self.assertIn("policy_route_setup", backend)
        self.assertIn("policy_route_clear", backend)
        self.assertIn('ip -4 rule add pref "$ROUTE_RULE_PREF" from "$IP/32" lookup "$ROUTE_TABLE"', backend)
        self.assertIn('ip -4 rule del pref "$1" from "$2/32" lookup "$3"', backend)
        self.assertIn('if ($i == "iif" && $(i + 1) == dev)', backend)
        self.assertIn('route[0].nexthop', backend)
        self.assertIn('alphabet = "_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"', backend)
        self.assertNotIn('| cksum', backend)
        self.assertIn("stale_policy_clear", backend)
        self.assertIn("policy_state_write", backend)
        self.assertIn("table_has_default", backend)
        self.assertIn("policy_rule_delete", backend)
        self.assertIn('from "$2/32" lookup "$3"', backend)
        self.assertIn('ROUTE_GATEWAY', backend)
        self.assertIn('"$GATEWAY/32" dev "$DEVICE" scope link', backend)
        self.assertIn('ROUTE_GATEWAY=', backend)
        self.assertLess(backend.index('stale_policy_clear || exit 1'), backend.index("trap cleanup EXIT"))

    def test_package_installs_full_iproute_support(self):
        makefile = self.read("Makefile")
        self.assertIn("+ip-full", makefile)

    def test_luci_supports_add_remove_and_interface_validation(self):
        luci = self.read("root/usr/lib/lua/luci/model/cbi/hbasstunet.lua")
        self.assertIn('TypedSection, "hbasstunet"', luci)
        self.assertIn("s.addremove = true", luci)
        self.assertIn("function i.validate", luci)
        self.assertIn('s.template = "hbasstunet/tsection"', luci)
        self.assertIn("绑定其源 IPv4", luci)

    def test_status_cards_expose_runtime_information(self):
        controller = self.read("root/usr/lib/lua/luci/controller/hbasstunet.lua")
        template = self.read("root/usr/lib/lua/luci/view/hbasstunet/tsection.htm")
        self.assertIn("function status()", controller)
        self.assertIn("function reauth()", controller)
        self.assertIn("hbasstunet-card-delete", template)
        self.assertIn("hbasstunet-card-reauth", template)
        self.assertIn("账号 #%", template)
        for field in ("operator", "message", "dial_code"):
            self.assertIn(field, template)

    def test_reauth_supports_anonymous_uci_sections(self):
        controller = self.read("root/usr/lib/lua/luci/controller/hbasstunet.lua")
        self.assertIn('uci:get_all("hbasstunet", section)', controller)
        self.assertIn('account[".type"] ~= "hbasstunet"', controller)

    def test_update_panel_has_spacing_and_button_layout(self):
        template = self.read("root/usr/lib/lua/luci/view/hbasstunet/update.htm")
        self.assertIn("hbasstunet-update-actions", template)
        self.assertIn("padding: 1rem", template)
        self.assertIn("gap: .6rem", template)

    def test_credentials_and_outputs_are_ignored(self):
        ignore = self.read(".gitignore")
        for pattern in ("/output/", ".env", "*.cookie", "*.session", "*.token"):
            self.assertIn(pattern, ignore)


if __name__ == "__main__":
    unittest.main()
