#!/usr/bin/env bash
# Keep FlClash TUN working with Tailscale:
# tailscaled uses fwmark 0x80000 which forces lookup of the main table.
# Fake-IP destinations must still land on FlClash, otherwise they go out the Wi-Fi
# gateway and time out.
set -euo pipefail
IFACE="${FLCLASH_IFACE:-FlClash}"
CIDR="${FAKEIP_CIDR:-198.18.0.0/16}"
if ! ip link show "$IFACE" >/dev/null 2>&1; then
  echo "interface $IFACE not found" >&2
  exit 1
fi
ip route replace "$CIDR" dev "$IFACE"
echo "ok: $CIDR -> dev $IFACE (main table)"
ip route get 198.18.0.10 mark 0x80000
