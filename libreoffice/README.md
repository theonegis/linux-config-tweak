# LibreOffice + ZorinGreen-Light

Local `~/.local/share/applications/libreoffice-*.desktop` launchers force:

```
GTK_THEME=ZorinGreen-Light SAL_USE_VCLPLUGIN=gtk3
```

so menus/dialogs follow the Zorin GTK theme (LibreOffice cannot load it as a full skin).

Re-apply after Fedora package updates overwrite user launchers:

```bash
sed -i 's/GTK_THEME=Adwaita/GTK_THEME=ZorinGreen-Light/g' \
  ~/.local/share/applications/libreoffice-*.desktop
# or if missing, copy from /usr/share/applications and inject:
# Exec=/usr/bin/env GTK_THEME=ZorinGreen-Light SAL_USE_VCLPLUGIN=gtk3 /usr/bin/libreoffice ...
update-desktop-database ~/.local/share/applications
```

## Notebookbar section labels (upright, not italic)

LibreOffice marks group captions (剪贴板 / 字体 / 段落 …) as italic in
`notebookbar*.ui`. This overlays upright labels into:

`~/.config/libreoffice/4/user/config/soffice.cfg/...`

```bash
./libreoffice/deitalicize-notebookbar.sh
```

Then fully quit and reopen LibreOffice. Re-run after major LO upgrades if captions go italic again.
