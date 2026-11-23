#!/usr/bin/env bash
set -euo pipefail
if (( EUID != 0 )); then
    echo '请通过 sudo bash 运行此脚本。' >&2
    exit 1
fi
python3 - <<'PY'
from pathlib import Path
from datetime import datetime
import shutil
import subprocess

paths = [Path('/etc/profile.d/fcitx5.sh'), Path('/etc/X11/xinit/xinput.d/fcitx5.conf')]
changes = {}
for path in paths:
    original = path.read_text()
    updated = ''.join(line for line in original.splitlines(keepends=True)
                      if not line.strip().startswith(('export GTK_IM_MODULE=', 'GTK_IM_MODULE=')))
    subprocess.run(['/bin/sh', '-n'], input=updated, text=True, check=True)
    if updated != original:
        changes[path] = updated
if changes:
    backup = Path('/var/backups/fcitx5-env-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    backup.mkdir(parents=True, exist_ok=False)
    for path in changes:
        shutil.copy2(path, backup / path.name)
    for path, updated in changes.items():
        with path.open('w') as target:
            target.write(updated)
        assert path.read_text() == updated
        print('已删除 GTK_IM_MODULE 赋值：', path)
    print('原文件备份：', backup)
else:
    print('两处配置均已清除 GTK_IM_MODULE 赋值。')
PY
echo '请注销桌面后重新登录，使所有应用使用新环境。'
