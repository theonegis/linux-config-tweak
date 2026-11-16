# Synology Drive CPU / I/O limits (Fedora)

The autostart entry applies three controls while preserving the laptop's Qt
scaling and font setup:

- `nice -n 19`: schedules Drive at the lowest normal CPU priority. It yields to
  interactive work, but does not cap the amount of CPU Drive can consume.
- `ionice -c 3`: schedules disk I/O only when the system has no higher-priority
  I/O. This can slow sync while the laptop is busy.
- `CPUQuota=30%`: caps the GNOME systemd app scope to 0.3 CPU cores. This limits
  CPU use directly and may make initial scans or large syncs take longer.

The user `synology-drive-reprio.path` watches for `~/.SynologyDrive/daemon.pid`
and triggers a oneshot service that applies `nice`/`ionice` to the daemon and
related Synology processes. The autostart entry is the only enabled Drive
launcher; `synology-drive.desktop` is hidden to avoid starting a duplicate.

Install/refresh the config from the repository root:

```sh
cp synology/.config/autostart/synology-drive-autostart.desktop ~/.config/autostart/
install -Dm755 synology/.local/bin/synology-drive-reprio ~/.local/bin/synology-drive-reprio
install -Dm644 synology/.config/systemd/user/synology-drive-reprio.path ~/.config/systemd/user/synology-drive-reprio.path
install -Dm644 synology/.config/systemd/user/synology-drive-reprio.service ~/.config/systemd/user/synology-drive-reprio.service
cp -a synology/.config/systemd/user.control/. ~/.config/systemd/user.control/
systemctl --user daemon-reload
systemctl --user enable --now synology-drive-reprio.path
```

The CPU quota drop-ins are persistent user-systemd properties for the GNOME
app scopes used by the two known desktop-entry IDs. A package or desktop
change can rename those transient units; check with `systemctl --user show
'<unit>' -p CPUQuotaPerSecUSec` if the cap appears ineffective.

These settings manage scheduling and resource limits. They do not reduce the
amount of file scanning or synchronization work. If Drive still uses its full
quota continuously, reduce the synced folder scope or exclude frequently
changing/cache directories in Drive Client preferences. The client log on this
machine also showed repeated long-poll failures with fallback polling; check
NAS/network reachability if CPU remains busy while idle.

## Per-computer Qt scaling

`QT_SCALE_FACTOR` is machine-specific. The repository desktop entries use 2.0
for the 200% setup; this MacBook's live autostart entry uses 1.75. Before
copying an entry to another computer, set the value for that laptop's display.
Do not copy the repository entry over a machine-local entry without checking
its scale first.
