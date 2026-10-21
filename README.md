# TopStats

A native Omarchy bar widget for **CPU, GPU, and RAM** with a compact
TopHat-style readout and a matching details panel.

TopStats shows the three metrics as icon + percentage + micro meter in the
bar. Clicking a metric opens a theme-aware card with capacity bars, a
two-minute history chart, top processes, and uptime. The layout and visual
language are inspired by the GNOME [TopHat](https://github.com/fflewddur/tophat)
extension; the implementation is original Omarchy/Quickshell QML.

![TopStats preview](preview.png)

## Features

- CPU utilization, per-core bars, frequency, package temperature, and uptime.
- NVIDIA GPU utilization, VRAM, temperature, power, driver, and per-process
  GPU activity (via `nvidia-smi pmon`).
- AMD GPU support through `amdgpu` sysfs (`gpu_busy_percent`,
  `mem_info_vram_*`, hwmon temperature and power).
- RAM and swap usage with available/total sizes.
- Top processes by instantaneous CPU use, resident memory, or GPU activity.
- Two-minute history charts with the same 100/50/0 scale as TopHat.
- Follows the active Omarchy theme, font, corner radius, and accent color.
- Hover tooltips on each bar metric.
- No root, no background daemon, and no network access.

## Requirements

- Omarchy Quattro (4.x) with the Quickshell shell.
- **NVIDIA:** `nvidia-utils` supplies `nvidia-smi` (normally already installed).
- **AMD:** no extra package; reads `/sys/class/drm/...`.
- **btop:** optional, only for the terminal button in the panel. It is already
  present on most Omarchy systems; install it with your package manager if not.

If no supported GPU is found, the GPU segment and tab are hidden automatically.

## Install

```bash
omarchy plugin add https://github.com/KaplanHalil/omarchy-topstats.git --enable
```

If the widget is not placed automatically:

```bash
omarchy plugin enable io.github.kaplanhalil.topstats --section right --before omarchy.power
```

You can also drag it in the bar, or move it later with:

```bash
omarchy bar move io.github.kaplanhalil.topstats --section right
```

## Use

- **Left click** a metric: open the details panel on CPU, GPU, or RAM.
- **Right click** a metric: open btop.
- **Esc**: close the panel.
- **Left/Right** (or `h`/`l`): switch tabs.
- **1 / 2 / 3**: jump to CPU / GPU / RAM.
- **r**: refresh the process lists.
- **s**: toggle the settings page.
- The round buttons at the bottom open btop and the settings page.

The bar automatically switches to a compact icon + meter layout when the bar
is placed on the left or right edge.

## Settings

Open the gear in the panel, or edit the widget entry in
`~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.kaplanhalil.topstats",
  "showValues": true,
  "cpuStyle": "meter",
  "gpuDevice": "auto",
  "interval": 1000,
  "gpuInterval": 2000
}
```

| Key | Default | Values | Meaning |
| --- | --- | --- | --- |
| `showValues` | `true` | boolean | Show percentages beside the icons |
| `cpuStyle` | `"meter"` | `"meter"`, `"cores"` | Single bar or one bar per logical CPU |
| `gpuDevice` | `"auto"` | `"auto"`, `"nvidia"`, `"amd"`, `"off"` | GPU backend |
| `interval` | `1000` | milliseconds ≥ 500 | CPU/RAM sampling interval |
| `gpuInterval` | `2000` | milliseconds ≥ 1000 | GPU polling interval |

Settings changed in the panel are written back to `shell.json` through
Omarchy's normal bar-entry update path.

> **GPU power note:** every `nvidia-smi` call briefly wakes the discrete GPU.
> The default 2-second interval is responsive; raise `gpuInterval` to 5–10
> seconds if idle power matters more than chart resolution.

## How it reads data

| Metric | Source |
| --- | --- |
| CPU | `/proc/stat` deltas, `/proc/cpuinfo`, `coretemp`/`k10temp` hwmon |
| RAM / swap | `/proc/meminfo` (`used = total - available`) |
| NVIDIA | `nvidia-smi --query-gpu`, `nvidia-smi pmon` for processes |
| AMD | `/sys/class/drm/card*/device/` sysfs |
| Processes | `/proc/<pid>` via `ps` (CPU is an instantaneous delta, not a lifetime average) |
| Uptime | `/proc/uptime` |

All sampling happens locally. TopStats opens no network connections and does
not request elevated privileges.

## Remove

```bash
omarchy plugin remove io.github.kaplanhalil.topstats
```

## Development

```bash
PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.kaplanhalil.topstats"
omarchy plugin validate "$PLUGIN_DIR"
omarchy-shell shell rescanPlugins
```

Quickshell resolves `qs.Commons` and `qs.Ui` from the shell directory; plain
`qmllint` needs a small module root that mirrors that mapping:

```bash
LINT_ROOT="${XDG_RUNTIME_DIR:-/tmp}/topstats-qml"
mkdir -p "$LINT_ROOT/qs"
ln -sfn "$OMARCHY_PATH/shell/Commons" "$LINT_ROOT/qs/Commons"
ln -sfn "$OMARCHY_PATH/shell/Ui" "$LINT_ROOT/qs/Ui"
qmllint -I "$LINT_ROOT" "$PLUGIN_DIR"/*.qml
```

The plugin folder must be at the repository root: `manifest.json`,
`BarWidget.qml`, and `Panel.qml` are loaded directly from it.

## Credits and license

TopStats is an independent implementation for Omarchy. Its bar meters,
history chart, and panel composition are inspired by
[GNOME TopHat](https://github.com/fflewddur/tophat) by Todd Kulesza
(GPL-3.0). No TopHat code, icons, or other assets are included here; the icons
are drawn as original SVG paths.

TopStats is released under the MIT license. See [LICENSE](LICENSE).
