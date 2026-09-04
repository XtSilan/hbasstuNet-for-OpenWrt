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

    def test_luci_supports_add_remove_and_interface_validation(self):
        luci = self.read("root/usr/lib/lua/luci/model/cbi/hbasstunet.lua")
        self.assertIn('TypedSection, "hbasstunet"', luci)
        self.assertIn("s.addremove = true", luci)
        self.assertIn("function i.validate", luci)

    def test_credentials_and_outputs_are_ignored(self):
        ignore = self.read(".gitignore")
        for pattern in ("/output/", ".env", "*.cookie", "*.session", "*.token"):
            self.assertIn(pattern, ignore)


if __name__ == "__main__":
    unittest.main()
