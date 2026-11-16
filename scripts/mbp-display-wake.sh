#!/bin/sh
# Manual suspend helpers for MBP16,3. Lid close no longer suspends.
# Also restarts tiny-dfr after resume: it is BindsTo= Touch Bar device
# units, which disappear during suspend and leave the daemon dead.
PATH=/sbin:/usr/sbin:/bin:/usr/bin
LOG=/var/log/mbp-display-wake.log
TB_XHCI=0000:06:00.0
USER_NAME=tanzhenyu
USER_HOME=/home/tanzhenyu
CONFIG_DIR="$USER_HOME/.config/input-remapper-2"
log() { echo "$(date -Is) $*" >> "$LOG"; }

reload_remapper() {
  uid=$(id -u "$USER_NAME" 2>/dev/null) || return 0
  runtime=/run/user/$uid
  sleep 2
  [ -d "$runtime" ] || return 0
  systemctl start input-remapper.service >/dev/null 2>&1 || true
  sudo -u "$USER_NAME" XDG_RUNTIME_DIR="$runtime" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" HOME="$USER_HOME" \
    input-remapper-control --command autoload --config-dir "$CONFIG_DIR" \
    >>"$LOG" 2>&1 || log "remapper autoload failed"
}

wake_display() {
  uid=$(id -u "$USER_NAME" 2>/dev/null) || return 0
  runtime=/run/user/$uid
  # Wait until user.slice is thawed / session usable
  i=0
  while [ $i -lt 50 ]; do
    if systemctl is-active --quiet "user@$uid.service" 2>/dev/null; then
      # user.slice thawed when systemd-sleep has finished freezing; small delay
      break
    fi
    i=$((i+1)); sleep 0.1
  done
  sleep 1
  if [ -w /sys/class/backlight/acpi_video0/brightness ]; then
    cur=$(cat /sys/class/backlight/acpi_video0/brightness)
    max=$(cat /sys/class/backlight/acpi_video0/max_brightness)
    [ "${cur:-0}" -le 0 ] && cur=$(( max * 60 / 100 ))
    echo "$cur" > /sys/class/backlight/acpi_video0/brightness
  fi
  if [ -d "$runtime" ]; then
    sudo -u "$USER_NAME" XDG_RUNTIME_DIR="$runtime" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" HOME="$USER_HOME" \
      WAYLAND_DISPLAY=wayland-0 \
      sh -c 'noctalia msg dpms-on; umbriel msg output-enable:eDP-1; /home/tanzhenyu/.local/bin/mbp-lid-open' \
      >>"$LOG" 2>&1 || log "wake_display cmds failed"
  fi
}

# tiny-dfr binds to Touch Bar device units. Suspend tears those units down and
# systemd stops the daemon; after resume the devices return but the service
# stays dead unless something starts it again.
restart_tiny_dfr() {
  i=0
  while [ $i -lt 50 ]; do
    if systemctl is-active --quiet dev-tiny_dfr_display.device \
      && systemctl is-active --quiet dev-tiny_dfr_backlight.device \
      && systemctl is-active --quiet dev-tiny_dfr_display_backlight.device; then
      break
    fi
    i=$((i + 1))
    sleep 0.2
  done
  systemctl reset-failed tiny-dfr.service >/dev/null 2>&1 || true
  if systemctl restart tiny-dfr.service >>"$LOG" 2>&1; then
    log "tiny-dfr restarted (waited ${i} ticks)"
  else
    log "tiny-dfr restart failed (waited ${i} ticks)"
  fi
}

case "$1" in
  pre)
    log "pre $2: unbind TB xHCI"
    [ -e "/sys/bus/pci/devices/$TB_XHCI/driver" ] && \
      echo "$TB_XHCI" > /sys/bus/pci/drivers/xhci_hcd/unbind 2>/dev/null || true
    ;;
  post)
    log "post $2"
    if [ -e "/sys/bus/pci/devices/$TB_XHCI" ] && [ ! -e "/sys/bus/pci/devices/$TB_XHCI/driver" ]; then
      echo "$TB_XHCI" > /sys/bus/pci/drivers/xhci_hcd/bind 2>/dev/null || true
    fi
    wake_display &
    reload_remapper &
    restart_tiny_dfr &
    ;;
esac
exit 0
