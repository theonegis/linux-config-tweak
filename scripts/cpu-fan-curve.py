#!/usr/bin/env python3
"""Drive the two ACPI fans from the hottest CPU temperature.

This process is what chooses the fan speed. Once a second it reads coretemp,
maps the hottest sensor through the curve below, and writes an integer to
each fan's cur_state file:

  /sys/class/thermal/cooling_deviceN/cur_state

cur_state is not a command. On this machine the kernel acpi-fan driver
multiplies it by 2 and passes that percentage to the ACPI _FSL method
(0 → 0%, 50 → 100%). The embedded controller (H_EC, TFN1/TFN2) then
changes the fans. On this Huawei MRG-WXX the firmware accepts the write and then ignores
it: cur_state reads back as 0 and the fan RPM does not move. The
embedded controller keeps its own curve. The systemd unit is installed
but disabled for that reason.

Curve, using the hottest package or core temperature:

  ≤75°C             0% (stopped)
  (75°C, 95°C)      exponential, k=3, from the 25% start step up to 100%
  ≥95°C             100%

25% is the first real step in the fan performance table (about 3200 RPM).
Values between 1% and 24% are not a stable speed, so the curve starts at
25% the moment the temperature crosses 75°C. After the fans are spinning
they stay at that minimum until the hottest sensor falls below 73°C, so
they do not click on and off around the threshold.

If the temperature cannot be read, both fans are set to 100%.
"""

from __future__ import annotations

import argparse
import math
import signal
import sys
import time
from pathlib import Path

START_C = 75.0
FULL_C = 95.0
STOP_C = 73.0
MIN_SPIN_PERCENT = 25.0
CURVE_K = 3.0
INTERVAL_S = 1.0

stop = False


def handle_stop(signum: int, _frame: object) -> None:
    del signum
    global stop
    stop = True


def log(message: str) -> None:
    print(message, flush=True)


def coretemp_hwmon() -> Path:
    for hwmon in Path("/sys/class/hwmon").glob("hwmon*"):
        name = hwmon / "name"
        if name.is_file() and name.read_text().strip() == "coretemp":
            return hwmon
    raise RuntimeError("找不到 coretemp 传感器")


def hottest_celsius() -> float:
    hwmon = coretemp_hwmon()
    temps = []
    for node in hwmon.glob("temp*_input"):
        raw = node.read_text().strip()
        if not raw:
            continue
        temps.append(int(raw) / 1000.0)
    if not temps:
        raise RuntimeError("coretemp 没有温度读数")
    return max(temps)


def fan_states() -> list[tuple[str, Path, int]]:
    found: list[tuple[str, Path, int]] = []
    for device in Path("/sys/class/thermal").glob("cooling_device*"):
        type_path = device / "type"
        state_path = device / "cur_state"
        max_path = device / "max_state"
        if not type_path.is_file() or not state_path.is_file() or not max_path.is_file():
            continue
        name = type_path.read_text().strip()
        if name not in {"TFN1", "TFN2"}:
            continue
        found.append((name, state_path, int(max_path.read_text().strip())))
    found.sort(key=lambda item: item[0])
    if len(found) != 2:
        names = ", ".join(name for name, _, _ in found) or "无"
        raise RuntimeError(f"需要 TFN1 和 TFN2，实际找到：{names}")
    return found


def target_percent(temp_c: float, spinning: bool) -> tuple[float, bool]:
    if temp_c >= FULL_C:
        return 100.0, True
    if temp_c > START_C:
        span = (temp_c - START_C) / (FULL_C - START_C)
        rise = (math.exp(CURVE_K * span) - 1.0) / (math.exp(CURVE_K) - 1.0)
        return MIN_SPIN_PERCENT + (100.0 - MIN_SPIN_PERCENT) * rise, True
    if spinning and temp_c > STOP_C:
        return MIN_SPIN_PERCENT, True
    return 0.0, False


def percent_to_state(percent: float, max_state: int) -> int:
    if max_state <= 0:
        raise RuntimeError(f"风扇 max_state 无效：{max_state}")
    state = int(round(percent * max_state / 100.0))
    return max(0, min(max_state, state))


def apply_percent(percent: float) -> list[tuple[str, int, int]]:
    applied = []
    for name, state_path, max_state in fan_states():
        state = percent_to_state(percent, max_state)
        state_path.write_text(f"{state}\n")
        applied.append((name, state, max_state))
    return applied


def run_full() -> None:
    applied = apply_percent(100.0)
    detail = ", ".join(f"{name}={state}/{max_state}" for name, state, max_state in applied)
    log(f"风扇设为 100% ({detail})")


def run_loop() -> None:
    signal.signal(signal.SIGTERM, handle_stop)
    signal.signal(signal.SIGINT, handle_stop)
    spinning = False
    last_report: tuple[int, int] | None = None
    while not stop:
        try:
            temp_c = hottest_celsius()
            percent, spinning = target_percent(temp_c, spinning)
        except Exception as exc:
            spinning = True
            percent = 100.0
            temp_c = float("nan")
            log(f"读温度失败，风扇拉满：{exc}")
        try:
            applied = apply_percent(percent)
        except Exception as exc:
            log(f"写风扇失败：{exc}")
            time.sleep(INTERVAL_S)
            continue
        state = applied[0][1]
        max_state = applied[0][2]
        written_percent = round(state * 100 / max_state)
        report = (written_percent, state)
        if report != last_report:
            detail = ", ".join(
                f"{name} cur_state={value}/{max_state}"
                for name, value, max_state in applied
            )
            shown = "不可用" if math.isnan(temp_c) else f"{temp_c:.1f}°C"
            log(f"最热核心 {shown} → {written_percent}% ({detail})")
            last_report = report
        time.sleep(INTERVAL_S)


def main() -> int:
    parser = argparse.ArgumentParser(description="按 CPU 温度控制 TFN1/TFN2")
    parser.add_argument(
        "--full",
        action="store_true",
        help="立刻把两颗风扇设为 100%% 后退出",
    )
    args = parser.parse_args()
    try:
        if args.full:
            run_full()
        else:
            run_loop()
    except Exception as exc:
        log(f"风扇控制退出：{exc}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
