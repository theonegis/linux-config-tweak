# 多机风扇 / 温度控制说明

三台机器都装 Fedora，但风扇接口完全不同。改曲线之前，先确认本机实际硬件，不要把某一台的脚本套到另一台上。

| 机器 | 典型识别 | 实际控风扇的组件 | 仓库里对应内容 |
| --- | --- | --- | --- |
| Huawei MateBook | ACPI `TFN1` / `TFN2` cooling device | 自写 `cpu-fan-curve.py`（若固件接受写入） | `scripts/cpu-fan-curve.py`、`systemd/cpu-fan-curve.service` |
| MacBook Pro（T2） | `applesmc` / `APP0001`，`fan1_manual` | **t2fanrd**，读 `/etc/t2fand.conf` | `t2fanrd/t2fand.conf` |
| Surface Laptop | 视机型而定（常为 ACPI / DPTF / 厂商驱动） | 先探测，再选方案；本仓库暂无通用脚本 | 见下方探测步骤 |

## 先看硬件，再动手

在目标机器上执行：

```bash
# 机型
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name

# ACPI 散热设备（MateBook 期望看到 TFN1/TFN2）
for d in /sys/class/thermal/cooling_device*; do
  echo "$(basename "$d") $(cat "$d/type") cur=$(cat "$d/cur_state") max=$(cat "$d/max_state")"
done

# hwmon / 风扇节点（MacBook 常见 applesmc + fan1_*）
for n in /sys/class/hwmon/hwmon*/name; do
  echo "$(cat "$n") -> $(dirname "$n")"
done
find /sys/devices -name 'fan*_manual' -o -name 'fan*_input' 2>/dev/null | head

# 谁在跑
systemctl is-active t2fanrd.service cpu-fan-curve.service 2>/dev/null || true
```

判断规则：

1. 有 `TFN1`/`TFN2` → 才考虑启用 `cpu-fan-curve`。
2. 有 `applesmc`/`APP0001` 且存在 `t2fanrd` → 用 `/etc/t2fand.conf`，**不要**再启用 `cpu-fan-curve`。
3. Surface 或其他机型若以上都对不上 → 先查 `sensors`、厂商文档或 DPTF，再写专用方案。

## MateBook：`cpu-fan-curve`

- 按 `coretemp` 最热核心映射到 `TFN1`/`TFN2` 的 `cur_state`。
- 曲线常量在脚本内：`START_C` / `FULL_C` / `STOP_C`（当前设计约 75°C 起步，100°C 拉满）。
- 安装：`sudo ./scripts/install-cpu-fan-curve.sh`
- 注意：部分华为机型固件会接受写入但实际忽略，EC 仍按自己的曲线转。日志里若长期「写风扇失败：…找到：无」，说明这台机根本没有 TFN 节点，服务应禁用。

在 MacBook 上启用该服务无效，只会每秒报找不到 TFN。

## MacBook Pro（T2）：`t2fanrd`

- 发行版服务：`t2fanrd.service`（本机 kernel 也常为 `*.t2.fc*`）。
- 配置：`/etc/t2fand.conf`。仓库样例：`t2fanrd/t2fand.conf`。
- 关键字段：`low_temp` 开始加速，`high_temp` 达到最大转速；`speed_curve` 可选 linear / exponential / logarithmic。
- 生效：改完配置后 `sudo systemctl restart t2fanrd`。
- 运行时可见 `fan1_manual=1`，由 daemon 写 `fan1_output`；这是正常现象，不是「卡死在手动」。

示例（拉满温度 100°C）：

```ini
[Fan1]
low_temp=78
high_temp=100
speed_curve=exponential
always_full_speed=false
```

把仓库样例装到系统：

```bash
sudo cp t2fanrd/t2fand.conf /etc/t2fand.conf
sudo systemctl restart t2fanrd
sudo systemctl disable --now cpu-fan-curve.service   # 若曾误装
```

## Surface Laptop

尚无与 MateBook/MacBook 共用的脚本。上机后按「先看硬件」一节确认冷却设备与现有守护进程（例如 `thermald`、厂商工具），再决定是写 ACPI 曲线、用现成工具，还是保持固件默认。确认方案后再补进本仓库。

## 常见误判

| 现象 | 更可能的原因 |
| --- | --- |
| 改了 `cpu-fan-curve` 的 `FULL_C`，MacBook 风扇行为不变 | MacBook 听的是 `t2fanrd` / `t2fand.conf` |
| `cpu-fan-curve` 日志刷「需要 TFN1 和 TFN2，实际找到：无」 | 当前机器不是 MateBook ACPI 风扇路径，应 disable 该服务 |
| 风扇一直很吵 | 先看 CPU 包装温度是否已接近该机 `high_temp`/`FULL_C`；曲线到顶是预期行为 |
| 服务重启时风扇突然呼一下 | 检查对应服务的 `ExecStop` 是否强制拉满（MateBook 单元里有 `--full`） |
