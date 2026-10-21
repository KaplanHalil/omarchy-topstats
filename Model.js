// Pure parsing and formatting helpers for TopStats.
//
// The sampler does the I/O; everything in here is a pure function so it can
// be exercised from a plain QML/JS shell and stays free of Quickshell types.

var HISTORY_LIMIT = 120

function clamp(value, low, high) {
  var n = Number(value)
  if (!isFinite(n)) return low
  return Math.max(low, Math.min(high, n))
}

function percent(value) {
  return clamp(value, 0, 100)
}

// /proc/stat exposes one aggregate line and one line per logical CPU. The
// guest time is already included in user/nice, so it is deliberately left out
// of the total to avoid counting it twice.
function parseProcStat(text) {
  var lines = String(text || "").split("\n")
  var aggregate = null
  var cores = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line.indexOf("cpu") !== 0) continue
    var parts = line.split(/\s+/)
    if (parts.length < 5) continue
    var values = []
    for (var j = 1; j < parts.length && j <= 8; j++) values.push(Number(parts[j]) || 0)
    while (values.length < 8) values.push(0)
    var total = values[0] + values[1] + values[2] + values[3]
      + values[4] + values[5] + values[6] + values[7]
    var idle = values[3] + values[4]
    var row = { total: total, idle: idle }
    if (parts[0] === "cpu") aggregate = row
    else cores.push(row)
  }
  return { aggregate: aggregate, cores: cores }
}

// Usage needs two samples. A missing/zero-width window means "no reading
// yet", which the bar renders as the last known value rather than a jump to 0.
function cpuUsage(current, previous) {
  if (!current || !previous) return null
  var totalDelta = current.total - previous.total
  var idleDelta = current.idle - previous.idle
  if (totalDelta <= 0) return null
  return percent(100 * (1 - idleDelta / totalDelta))
}

function cpuCoreUsages(current, previous) {
  var out = []
  if (!current || !previous) return out
  var count = Math.min(current.length, previous.length)
  for (var i = 0; i < count; i++) {
    var usage = cpuUsage(current[i], previous[i])
    out.push(usage === null ? 0 : usage)
  }
  return out
}

// Memory "used" follows the same convention as GNOME System Monitor and
// TopHat: total minus available, so reclaimable cache is not counted as
// pressure.
function parseMeminfo(text) {
  var values = ({})
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^([A-Za-z_()0-9]+):\s+(\d+)/)
    if (match) values[match[1]] = Number(match[2]) * 1024
  }
  var total = Number(values.MemTotal) || 0
  var available = Number(values.MemAvailable) || 0
  if (available <= 0 && values.MemFree !== undefined) {
    available = Number(values.MemFree) + (Number(values.Buffers) || 0) + (Number(values.Cached) || 0)
  }
  var used = Math.max(0, total - available)
  var swapTotal = Number(values.SwapTotal) || 0
  var swapFree = Number(values.SwapFree) || 0
  var swapUsed = Math.max(0, swapTotal - swapFree)
  return {
    total: total,
    available: available,
    used: used,
    percent: total > 0 ? percent(100 * used / total) : 0,
    swapTotal: swapTotal,
    swapFree: swapFree,
    swapUsed: swapUsed,
    swapPercent: swapTotal > 0 ? percent(100 * swapUsed / swapTotal) : 0
  }
}

// /proc/cpuinfo lists the current MHz of every logical CPU. Averaging keeps
// the number honest on hybrid parts where the P-cores and E-cores differ.
function parseCpuFrequency(text) {
  var matches = String(text || "").match(/cpu MHz\s*:\s*([0-9.]+)/g) || []
  if (matches.length === 0) return 0
  var sum = 0
  for (var i = 0; i < matches.length; i++) {
    var value = Number(matches[i].replace(/^[^:]*:\s*/, ""))
    if (isFinite(value)) sum += value
  }
  return matches.length > 0 ? sum / matches.length : 0
}

function parseCpuModel(text) {
  var match = String(text || "").match(/model name\s*:\s*(.+)/)
  return match ? match[1].trim() : ""
}

function parseUptime(text) {
  var parts = String(text || "").trim().split(/\s+/)
  var seconds = Number(parts[0])
  return isFinite(seconds) ? seconds : 0
}

function parseTemperature(text) {
  var milli = Number(String(text || "").trim())
  return isFinite(milli) && milli > 0 ? milli / 1000 : -1
}

// nvidia-smi --format=csv,noheader,nounits
// name, utilization.gpu, memory.used, memory.total, temperature.gpu,
// power.draw, driver_version
function parseNvidia(text) {
  var line = String(text || "").trim().split("\n")[0]
  if (!line) return null
  var parts = line.split(",")
  for (var i = 0; i < parts.length; i++) parts[i] = parts[i].trim()
  if (parts.length < 5) return null
  var usedMiB = toNumber(parts[2])
  var totalMiB = toNumber(parts[3])
  return {
    name: parts[0] || "NVIDIA GPU",
    percent: percent(toNumber(parts[1])),
    memUsed: usedMiB * 1024 * 1024,
    memTotal: totalMiB * 1024 * 1024,
    temp: toNumber(parts[4], -1),
    power: parts.length > 5 ? toNumber(parts[5], -1) : -1,
    driver: parts.length > 6 ? parts[6] : ""
  }
}

function toNumber(value, fallback) {
  var cleaned = String(value || "").replace(/[^0-9.+-]/g, "")
  if (cleaned === "" || cleaned === "+" || cleaned === "-") return fallback === undefined ? 0 : fallback
  var n = Number(cleaned)
  if (!isFinite(n)) return fallback === undefined ? 0 : fallback
  return n
}

// AMD exposes the same headline numbers through sysfs. The poll script emits
// one CSV line so the QML side has a single parser for both vendors.
// name, busy%, vram used bytes, vram total bytes, temp C, power W
function parseAmd(text) {
  var line = String(text || "").trim().split("\n")[0]
  if (!line) return null
  var parts = line.split(",")
  if (parts.length < 4) return null
  for (var i = 0; i < parts.length; i++) parts[i] = parts[i].trim()
  return {
    name: parts[0] || "AMD GPU",
    percent: percent(toNumber(parts[1])),
    memUsed: toNumber(parts[2]),
    memTotal: toNumber(parts[3]),
    temp: parts.length > 4 ? toNumber(parts[4], -1) : -1,
    power: parts.length > 5 ? toNumber(parts[5], -1) : -1,
    driver: "amdgpu"
  }
}

// nvidia-smi pmon -c 1 lists every process with a graphics or compute
// context, unlike --query-compute-apps which omits graphics clients such as
// the compositor and browser. Columns: gpu pid type sm mem enc dec jpg ofa
// command. A dash means the column does not apply to that context.
function parseNvidiaProcesses(text) {
  var out = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line || line.charAt(0) === "#") continue
    var parts = line.split(/\s+/)
    if (parts.length < 10) continue
    var gpu = toNumber(parts[3], 0)
    if (gpu <= 0) continue
    var name = parts.slice(9).join(" ")
    out.push({
      pid: Number(parts[1]),
      gpu: gpu,
      name: processName(name)
    })
  }
  out.sort(function(a, b) { return b.gpu - a.gpu })
  return out.slice(0, 7)
}

// ps reports cumulative CPU time as [[dd-]hh:]mm:ss. Converting it to seconds
// lets the sampler turn two snapshots into an instantaneous percentage, which
// is far more honest than ps's lifetime average %CPU column.
function parseCpuTime(value) {
  var text = String(value || "").trim()
  if (!text) return 0
  var days = 0
  var dash = text.indexOf("-")
  if (dash !== -1) {
    days = Number(text.slice(0, dash)) || 0
    text = text.slice(dash + 1)
  }
  var parts = text.split(":")
  var seconds = 0
  for (var i = 0; i < parts.length; i++) seconds = seconds * 60 + (Number(parts[i]) || 0)
  return days * 86400 + seconds
}

// One row: pid cumulative-cpu-time rss comm. The comm field is last because it
// can contain spaces.
function parseProcessSnapshot(text) {
  var out = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*(\d+)\s+(\S+)\s+(\d+)\s+(.+)$/)
    if (!match) continue
    out.push({
      pid: Number(match[1]),
      cpuSeconds: parseCpuTime(match[2]),
      memory: Number(match[3]) * 1024,
      name: processName(match[4])
    })
  }
  return out
}

function processName(value) {
  var name = String(value || "").trim()
  if (!name) return "unknown"
  // Full command lines (NVIDIA reports one) collapse to the executable name.
  if (name.indexOf("/") !== -1) {
    var pieces = name.split(/\s+/)
    name = pieces[0]
    var slash = name.lastIndexOf("/")
    if (slash !== -1) name = name.slice(slash + 1)
  }
  return name.length > 26 ? name.slice(0, 25) + "…" : name
}

function formatBytes(bytes, decimals) {
  var n = Number(bytes)
  if (!isFinite(n) || n < 0) return "—"
  if (n >= 1024 * 1024 * 1024) {
    return trimFixed(n / (1024 * 1024 * 1024), decimals === undefined ? 1 : decimals) + " GB"
  }
  if (n >= 1024 * 1024) {
    return trimFixed(n / (1024 * 1024), 0) + " MB"
  }
  if (n >= 1024) return trimFixed(n / 1024, 0) + " KB"
  return Math.round(n) + " B"
}

function trimFixed(value, decimals) {
  var text = Number(value).toFixed(decimals)
  if (text.indexOf(".") !== -1) text = text.replace(/\.?0+$/, "")
  return text
}

function formatPercent(value) {
  var n = Number(value)
  if (!isFinite(n)) return "—"
  return Math.round(n) + "%"
}

function formatFrequency(mhz) {
  var n = Number(mhz)
  if (!isFinite(n) || n <= 0) return "—"
  if (n >= 1000) return trimFixed(n / 1000, 2) + " GHz"
  return Math.round(n) + " MHz"
}

function formatTemperature(celsius) {
  var n = Number(celsius)
  if (!isFinite(n) || n < 0) return "—"
  return Math.round(n) + " °C"
}

function formatPower(watts) {
  var n = Number(watts)
  if (!isFinite(n) || n < 0) return "—"
  return trimFixed(n, 1) + " W"
}

function formatUptime(seconds) {
  var total = Math.max(0, Math.floor(Number(seconds) || 0))
  var days = Math.floor(total / 86400)
  var hours = Math.floor((total % 86400) / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  var parts = []
  if (days > 0) parts.push(days + (days === 1 ? " day" : " days"))
  if (hours > 0) parts.push(hours + (hours === 1 ? " hour" : " hours"))
  if (minutes > 0 && days === 0) parts.push(minutes + (minutes === 1 ? " minute" : " minutes"))
  if (parts.length === 0) return "less than a minute"
  return parts.join(" ")
}

function pushHistory(values, value, limit) {
  var out = Array.isArray(values) ? values.slice() : []
  var n = Number(value)
  out.push(isFinite(n) ? clamp(n, 0, 100) : 0)
  var max = limit || HISTORY_LIMIT
  while (out.length > max) out.shift()
  return out
}

function average(values) {
  if (!Array.isArray(values) || values.length === 0) return 0
  var sum = 0
  for (var i = 0; i < values.length; i++) sum += Number(values[i]) || 0
  return sum / values.length
}
