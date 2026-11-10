#!/bin/sh
# Root helper: keep the greetd VT from showing text between Noctalia Greeter
# and the desktop session. Safe to run more than once.
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root" >&2
  exit 1
fi

# 1. Wipe the text console as soon as the greeter session starts, before it
# parks stdio. The running greetd keeps this path, so the next greeter picks
# the change up without a daemon restart.
session=/usr/bin/noctalia-greeter-session
if ! grep -q 'quiet-greeter-handoff' "$session"; then
  cp -a "$session" "${session}.bak.quiet-handoff"
  tmp=$(mktemp)
  awk '
    BEGIN { inserted = 0 }
    !inserted && /^_pass_log_env=0$/ {
      print "# quiet-greeter-handoff: drop leftover VT text before the greeter covers it."
      print "printf \"\\033[2J\\033[3J\\033[H\" 2>/dev/null || true"
      inserted = 1
    }
    { print }
    END {
      if (!inserted) exit 1
    }
  ' "$session" > "$tmp"
  cat "$tmp" > "$session"
  chmod 755 "$session"
  rm -f "$tmp"
  restorecon "$session" 2>/dev/null || true
fi

# 2. pam_oo7 starts oo7-daemon-login with the session VT as stdout/stderr.
# Its tracing does not go to the journal, so those lines are the flash.
helper=/usr/libexec/oo7-daemon-login
real=/usr/libexec/oo7-daemon-login.real
if [ ! -f "$real" ]; then
  mv "$helper" "$real"
fi
cat > "$helper" <<'EOF'
#!/bin/sh
# quiet-greeter-handoff: this helper inherits tty1 from greetd.
exec /usr/libexec/oo7-daemon-login.real "$@" >/dev/null 2>&1
EOF
chmod 755 "$helper"
chown root:root "$helper"
if [ -f "$real" ]; then
  chcon --reference="$real" "$helper" 2>/dev/null || true
fi
restorecon "$helper" "$real" 2>/dev/null || true

echo "quiet-greeter-handoff installed"
