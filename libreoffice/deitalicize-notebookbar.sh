#!/usr/bin/env bash
# Overlay upright Notebookbar section labels into the user LibreOffice config.
set -euo pipefail
SRC=/usr/lib64/libreoffice/share/config/soffice.cfg
USERCFG="${XDG_CONFIG_HOME:-$HOME/.config}/libreoffice/4/user/config/soffice.cfg"
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  rel="${f#$SRC/}"
  dest="$USERCFG/$rel"
  mkdir -p "$(dirname "$dest")"
  sed 's/<attribute name="style" value="italic"\/>/<attribute name="style" value="normal"\/>/g' "$f" > "$dest"
  echo "wrote $dest"
done < <(rg -l 'attribute name="style" value="italic"' "$SRC" --glob '**/notebookbar*.ui' || true)
# Also refresh any already-normal system files that we may want to keep synced:
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if rg -q 'attribute name="style" value="normal"' "$f"; then
    rel="${f#$SRC/}"
    dest="$USERCFG/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -a "$f" "$dest"
    echo "synced $dest"
  fi
done < <(find "$SRC" -path '*/ui/notebookbar*.ui' -type f | sort)
echo "Done. Fully quit LibreOffice (including quickstarter) and reopen."
