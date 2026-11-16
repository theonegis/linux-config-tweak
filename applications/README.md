# Synology Drive HiDPI (Umbriel)

Synology Drive Client is Qt5/X11. With Umbriel `xwayland_native_resolution = true`,
it sees the physical pixel grid and ignores compositor fractional scale
(currently eDP-1 `scale = 1.75`), so the UI looks tiny.

## Fix

Launch with:

```
QT_AUTO_SCREEN_SCALE_FACTOR=0 QT_SCALE_FACTOR=1.75
```

Install:

```bash
cp applications/synology-drive.desktop ~/.local/share/applications/
# Replace the vendor symlink under ~/.config/autostart/ (do not leave the
# /opt/Synology/... symlink — it starts without QT_SCALE_FACTOR and wins).
rm -f ~/.config/autostart/synology-drive-autostart.desktop
cp applications/synology-drive-autostart.desktop ~/.config/autostart/
# Optional: hide any duplicate synology-drive.desktop autostart entry.
update-desktop-database ~/.local/share/applications
env QT_AUTO_SCREEN_SCALE_FACTOR=0 QT_SCALE_FACTOR=1.75 synology-drive restart
```

After a Synology package upgrade, re-check that the autostart entry is still a
real file (not a symlink back to `/opt/Synology/...`).
