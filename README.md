# 自用的Linux系统及APP优化美化

我目前使用Fedora系统，默认安装的是GNOME，我自己安装了Umbriel窗口合成器。Umbriel窗口合成器的登录和桌面主题使用Noctalia。

我希望尽可能地减少去折腾Linux，而把它当成生产力工具去使用，所以能用现成的就用现成的。

但是我使用的系统希望整体设计是和谐美观的，简单优雅，能高效工作就行。

## 常用配置
文件管理器使用Strata，终端使用Kitty，编辑器常用Vim和VS Code

Office软件使用GenOffice，IDE有了AI之后使用的也不是很多了

输入法在GNOME使用IBus+Rime，在Umbriel使用Fcitx5+Rime，系统字体喜欢苹方和OPPO Sans

- Umbriel桌面默认配置文件的修改
- Kitty终端的简单配置
- Vim编辑器的简单配置
- 系统字体配置文件
- Umbriel下对Fcitx5 SVG主题支持在某些APP下有问题，修改启动环境可以修复
`Exec=env -u QT_IM_MODULES -u GTK_IM_MODULE QT_QPA_PLATFORM=wayland QT_IM_MODULE=text-input-unstable-v3 /usr/bin/wechat %U`

## 键盘映射

使用`input-remapper`把不常用的Caps按键映射为macOS的行为（因为我的主力电脑是macOS，这样可以保持行为的一致性）

使用`input-remapper`把不常用的Caps按键映射为鼠标左键，这样按住Caps就可以做选中，拖动了，比默认的双击拖动好用一些（目前没有在这样使用）

## 风扇 / 温度控制（多机注意）

三台 Fedora 笔记本硬件不同，风扇控制不能共用一套脚本：

- **Huawei MateBook**：ACPI `TFN1`/`TFN2` → `scripts/cpu-fan-curve.py`
- **MacBook Pro（T2）**：`applesmc` + **t2fanrd** → `t2fanrd/t2fand.conf`（安装为 `/etc/t2fand.conf`）
- **Surface Laptop**：先探测本机冷却设备，再选方案（仓库暂无通用脚本）

改曲线前先确认机型和现有守护进程。详细说明、探测命令与常见误判见 [docs/fan-control.md](docs/fan-control.md)。

## MacBook Pro 休眠与 Touch Bar

休眠唤醒后 Touch Bar 变黑，是因为 `tiny-dfr` 被停掉后没有自动拉起。修复脚本与安装方式见 [docs/mbp-sleep.md](docs/mbp-sleep.md)：

```bash
sudo ./scripts/install-mbp-display-wake.sh
```

