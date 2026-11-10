#!/bin/sh
# Install the CPU fan curve as a root systemd service.
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root" >&2
  exit 1
fi

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
install -m 755 "$repo/scripts/cpu-fan-curve.py" /usr/local/sbin/cpu-fan-curve.py
install -m 644 "$repo/systemd/cpu-fan-curve.service" /etc/systemd/system/cpu-fan-curve.service
restorecon /usr/local/sbin/cpu-fan-curve.py /etc/systemd/system/cpu-fan-curve.service 2>/dev/null || true
systemctl daemon-reload
systemctl enable --now cpu-fan-curve.service
systemctl --no-pager --full status cpu-fan-curve.service
