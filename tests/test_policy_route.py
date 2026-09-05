import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import re


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "root/usr/sbin/hbasstunet"


@unittest.skipIf(os.name == "nt", "POSIX shell integration test runs in CI")
class PolicyRouteIntegrationTests(unittest.TestCase):
    def run_harness(self):
        source = BACKEND.read_text(encoding="utf-8")
        functions = source.split('mkdir -p "$BASE"', 1)[0]
        harness = r'''
MOCK_ROOT=$(mktemp -d)
MOCK_RULES="$MOCK_ROOT/rules"
MOCK_LOG="$MOCK_ROOT/log"
cat > "$MOCK_RULES" <<'EOF'
1001: from all iif eth_a lookup 1
1003: from all iif eth_b lookup 3
2001: from all fwmark 0x100/0x3f00 lookup 1
2003: from all fwmark 0x300/0x3f00 lookup 3
EOF
ip() {
    case "$*" in
        "-4 rule show") cat "$MOCK_RULES" ;;
        "-4 route show table 1") echo "default via 10.0.0.1 dev eth_a src 10.0.0.2" ;;
        "-4 route show table 3") echo "default via 10.0.0.1 dev eth_b src 10.0.0.3" ;;
        "-4 route show table all")
            echo "default via 10.0.0.1 dev eth_a table 1 src 10.0.0.2"
            echo "default via 10.0.0.1 dev eth_b table 3 src 10.0.0.3"
            ;;
        "-4 rule add "*)
            echo "ADD $*" >> "$MOCK_LOG"
            echo "$5: from ${7%/32} lookup $9" >> "$MOCK_RULES"
            ;;
        "-4 rule del "*) echo "DEL $*" >> "$MOCK_LOG" ;;
        "-4 route flush "*|"-4 route replace "*) echo "ROUTE $*" >> "$MOCK_LOG" ;;
        "-4 route show table "*) return 0 ;;
        *) echo "unexpected ip command: $*" >&2; return 1 ;;
    esac
}
run_account() {
    SECTION=$1
    DEVICE=$2
    IP=$3
    BASE="$MOCK_ROOT/$SECTION"
    ROUTE_STATE_FILE="$BASE/route_policy"
    mkdir -p "$BASE"
    ROUTE_TABLE=
    ROUTE_RULE_PREF=
    OWN_ROUTE_TABLE=0
    GATEWAY=10.0.0.1
    ROUTE_GATEWAY=
    policy_route_setup
    echo "$SECTION:$IP:$ROUTE_TABLE"
    policy_route_clear
}
run_ip_change() {
    SECTION=changing
    DEVICE=eth_a
    BASE="$MOCK_ROOT/$SECTION"
    ROUTE_STATE_FILE="$BASE/route_policy"
    mkdir -p "$BASE"
    ROUTE_TABLE=
    ROUTE_RULE_PREF=
    OWN_ROUTE_TABLE=0
    GATEWAY=10.0.0.1
    ROUTE_GATEWAY=
    IP=10.0.0.20
    policy_route_setup
    policy_route_clear
    IP=10.0.0.21
    policy_route_setup
    policy_route_clear
}
run_account account_a eth_a 10.0.0.2
run_account account_b eth_b 10.0.0.3
run_account account_c eth_c 10.0.0.4
run_ip_change
cat "$MOCK_LOG"
rm -rf "$MOCK_ROOT"
'''
        with tempfile.TemporaryDirectory() as temp_dir:
            script = Path(temp_dir) / "policy-test.sh"
            script.write_text(functions + harness, encoding="utf-8", newline="\n")
            return subprocess.run(
                ["/bin/sh", str(script)],
                check=True,
                text=True,
                capture_output=True,
            ).stdout

    def test_two_sources_use_their_matching_tables_and_cleanup(self):
        output = self.run_harness()
        self.assertIn("account_a:10.0.0.2:1", output)
        self.assertIn("account_b:10.0.0.3:3", output)
        self.assertRegex(output, r"ADD -4 rule add pref \d+ from 10\.0\.0\.2/32 lookup 1")
        self.assertRegex(output, r"ADD -4 rule add pref \d+ from 10\.0\.0\.3/32 lookup 3")
        self.assertRegex(output, r"DEL -4 rule del pref \d+ from 10\.0\.0\.2/32 lookup 1")
        self.assertRegex(output, r"DEL -4 rule del pref \d+ from 10\.0\.0\.3/32 lookup 3")

    def test_interface_without_mwan3_gets_private_table(self):
        output = self.run_harness()
        match = re.search(r"account_c:10\.0\.0\.4:(11\d{3})", output)
        self.assertIsNotNone(match)
        table = match.group(1)
        self.assertIn(
            f"ROUTE -4 route replace table {table} 10.0.0.1/32 dev eth_c scope link src 10.0.0.4",
            output,
        )
        self.assertIn(
            f"ROUTE -4 route replace table {table} default via 10.0.0.1 dev eth_c src 10.0.0.4",
            output,
        )
        self.assertIn(f"ROUTE -4 route flush table {table}", output)

    def test_ipv4_change_removes_old_rule_and_adds_new_rule(self):
        output = self.run_harness()
        self.assertRegex(output, r"ADD -4 rule add pref \d+ from 10\.0\.0\.20/32 lookup 1")
        self.assertRegex(output, r"DEL -4 rule del pref \d+ from 10\.0\.0\.20/32 lookup 1")
        self.assertRegex(output, r"ADD -4 rule add pref \d+ from 10\.0\.0\.21/32 lookup 1")


if __name__ == "__main__":
    unittest.main()
