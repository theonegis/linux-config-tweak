# MacBook Pro 16,3：休眠 / Touch Bar

## Touch Bar 休眠后黑屏

`tiny-dfr` 的 unit 使用 `BindsTo=` 绑定 `dev-tiny_dfr_*.device`。休眠时这些设备单元消失，systemd 会停掉 daemon；唤醒后设备回来，服务却不会自动再起。

修复：在 `system-sleep` 的 `post` 阶段等待设备就绪后执行 `systemctl restart tiny-dfr`。

```bash
sudo ./scripts/install-mbp-display-wake.sh
```

会安装 `/usr/lib/systemd/system-sleep/mbp-display-wake.sh`（仓库源文件：`scripts/mbp-display-wake.sh`）。

验证：休眠再唤醒，Touch Bar 应自动亮起；日志里应有 `tiny-dfr restarted`：

```bash
tail -20 /var/log/mbp-display-wake.log
systemctl is-active tiny-dfr.service
```

临时手动恢复：

```bash
sudo systemctl restart tiny-dfr
```
