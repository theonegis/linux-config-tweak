#!/bin/sh
# Install the MBP16,3 systemd-sleep display / Touch Bar wake helper.
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root" >&2
  exit 1
fi

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
install -m 755 "$repo/scripts/mbp-display-wake.sh" \
  /usr/lib/systemd/system-sleep/mbp-display-wake.sh
restorecon /usr/lib/systemd/system-sleep/mbp-display-wake.sh 2>/dev/null || true
echo "installed /usr/lib/systemd/system-sleep/mbp-display-wake.sh"
