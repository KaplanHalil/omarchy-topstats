import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// TopStats sampler.
//
// One instance lives inside each bar widget. CPU and memory are cheap file
// reads once a second; GPU is polled less often because nvidia-smi has to
// wake the card. Top-process lists only run while the details panel is open.
Item {
  id: root
  visible: false
  width: 0
  height: 0

  property int interval: 1000
  property int gpuInterval: 2000
  property string gpuMode: "auto"
  property bool panelOpen: false
  property bool gpuPanelVisible: false

  // CPU ---------------------------------------------------------------
  property real cpuPercent: 0
  property var cpuCores: []
  property real cpuFrequency: 0
  property string cpuName: ""
  property real cpuTemp: -1
  property var cpuHistory: []
  property var previousCpu: null
  property string cpuTempPath: ""

  // Memory ------------------------------------------------------------
  property var memory: ({
    total: 0,
    available: 0,
    used: 0,
    percent: 0,
    swapTotal: 0,
    swapUsed: 0,
    swapPercent: 0
  })
  property var memoryHistory: []

  // GPU ---------------------------------------------------------------
  property string gpuVendor: ""
  property string gpuName: ""
  property bool gpuAvailable: false
  property real gpuPercent: 0
  property real gpuMemUsed: 0
  property real gpuMemTotal: 0
  property real gpuTemp: -1
  property real gpuPower: -1
  property string gpuDriver: ""
  property var gpuHistory: []
  property var topGpu: []

  // Processes / uptime ------------------------------------------------
  property var topCpu: []
  property var topMemory: []
  property real uptime: 0
  property var previousProcessTimes: ({})
  property real previousProcessAt: 0

  readonly property int historyLimit: Math.max(12, Math.round(120000 / Math.max(500, interval)))
  readonly property int gpuHistoryLimit: Math.max(12, Math.round(120000 / Math.max(1000, gpuInterval)))

  function sampleFast() {
    statFile.reload()
    memFile.reload()
    freqFile.reload()
    uptimeFile.reload()
  }

  function applyStat(text) {
    var current = Model.parseProcStat(text)
    if (!current.aggregate) return

    var usage = Model.cpuUsage(current.aggregate, root.previousCpu ? root.previousCpu.aggregate : null)
    if (usage !== null) {
      root.cpuPercent = usage
      root.cpuHistory = Model.pushHistory(root.cpuHistory, usage, root.historyLimit)
    }

    if (root.previousCpu) {
      var cores = Model.cpuCoreUsages(current.cores, root.previousCpu.cores)
      if (cores.length > 0) root.cpuCores = cores
    }
    root.previousCpu = current
  }

  function applyMemory(text) {
    var next = Model.parseMeminfo(text)
    if (!next.total) return
    root.memory = next
    root.memoryHistory = Model.pushHistory(root.memoryHistory, next.percent, root.historyLimit)
  }

  function setPanelOpen(value) {
    if (root.panelOpen === value) return
    root.panelOpen = value
    if (value) {
      refreshProcesses()
    } else {
      root.gpuPanelVisible = false
      root.previousProcessTimes = ({})
      root.previousProcessAt = 0
      root.topCpu = []
      root.topGpu = []
    }
  }

  function setGpuPanelVisible(value) {
    if (root.gpuPanelVisible === value) return
    root.gpuPanelVisible = value
    if (value && root.panelOpen && root.gpuVendor === "nvidia" && !gpuApps.running) gpuApps.running = true
  }

  function refreshProcesses() {
    if (!root.panelOpen) return
    if (!processList.running) processList.running = true
  }

  function applyProcessSnapshot(text) {
    if (!root.panelOpen) return
    var rows = Model.parseProcessSnapshot(text)
    var now = Date.now()
    var elapsed = root.previousProcessAt > 0 ? (now - root.previousProcessAt) / 1000 : 0
    var previous = root.previousProcessTimes || ({})
    var next = ({})
    var cpuRows = []
    var memRows = []
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      next[row.pid] = row.cpuSeconds
      var before = previous[row.pid]
      row.cpu = (before !== undefined && elapsed > 0)
        ? Math.max(0, (row.cpuSeconds - before) / elapsed * 100)
        : 0
      cpuRows.push(row)
      memRows.push(row)
    }
    cpuRows.sort(function(a, b) { return b.cpu - a.cpu })
    memRows.sort(function(a, b) { return b.memory - a.memory })
    // The first snapshot only establishes a baseline. Showing it would rank
    // kernel threads at 0% for two seconds, which reads as a broken list.
    if (elapsed > 0) {
      var active = []
      for (var j = 0; j < cpuRows.length; j++) {
        var candidate = cpuRows[j]
        // Kernel threads have no resident memory and would otherwise pad the
        // list with 0% rows such as "7:1-events".
        if (candidate.cpu >= 0.5 && candidate.memory > 0) active.push(candidate)
        if (active.length === 7) break
      }
      root.topCpu = active
    }
    root.topMemory = memRows.slice(0, 7)
    root.previousProcessTimes = next
    root.previousProcessAt = now
  }

  function probeGpu() {
    root.gpuAvailable = false
    root.gpuVendor = ""
    root.gpuHistory = []
    root.topGpu = []
    root.gpuPercent = 0
    root.gpuMemUsed = 0
    root.gpuMemTotal = 0
    root.gpuTemp = -1
    root.gpuPower = -1
    if (root.gpuMode === "off") return
    if (root.gpuMode === "nvidia") {
      root.gpuVendor = "nvidia"
      root.gpuAvailable = true
      Qt.callLater(root.pollGpu)
      return
    }
    if (root.gpuMode === "amd") {
      root.gpuVendor = "amd"
      root.gpuAvailable = true
      Qt.callLater(root.pollGpu)
      return
    }
    if (!gpuProbe.running) gpuProbe.running = true
  }

  function applyGpuProbe(text) {
    if (root.gpuMode !== "auto") return
    var vendor = String(text || "").trim().split("\n")[0]
    if (vendor !== "nvidia" && vendor !== "amd") return
    root.gpuVendor = vendor
    root.gpuAvailable = true
    Qt.callLater(root.pollGpu)
  }

  function pollGpu() {
    if (!root.gpuAvailable) return
    if (root.gpuVendor === "nvidia" && !gpuNvidia.running) gpuNvidia.running = true
    else if (root.gpuVendor === "amd" && !gpuAmd.running) gpuAmd.running = true
  }

  function applyNvidia(text) {
    if (!root.gpuAvailable || root.gpuVendor !== "nvidia") return
    var next = Model.parseNvidia(text)
    if (!next) return
    root.gpuName = next.name
    root.gpuPercent = next.percent
    root.gpuMemUsed = next.memUsed
    root.gpuMemTotal = next.memTotal
    root.gpuTemp = next.temp
    root.gpuPower = next.power
    root.gpuDriver = next.driver
    root.gpuHistory = Model.pushHistory(root.gpuHistory, next.percent, root.gpuHistoryLimit)
  }

  function applyAmd(text) {
    if (!root.gpuAvailable || root.gpuVendor !== "amd") return
    var next = Model.parseAmd(text)
    if (!next) return
    root.gpuName = next.name
    root.gpuPercent = next.percent
    root.gpuMemUsed = next.memUsed
    root.gpuMemTotal = next.memTotal
    root.gpuTemp = next.temp
    root.gpuPower = next.power
    root.gpuDriver = next.driver
    root.gpuHistory = Model.pushHistory(root.gpuHistory, next.percent, root.gpuHistoryLimit)
  }

  onGpuModeChanged: probeGpu()
  onHistoryLimitChanged: {
    if (cpuHistory.length > historyLimit) cpuHistory = cpuHistory.slice(-historyLimit)
    if (memoryHistory.length > historyLimit) memoryHistory = memoryHistory.slice(-historyLimit)
  }
  onGpuHistoryLimitChanged: {
    if (gpuHistory.length > gpuHistoryLimit) gpuHistory = gpuHistory.slice(-gpuHistoryLimit)
  }
  Component.onCompleted: {
    probeGpu()
    probeTemperature()
  }

  Timer {
    id: fastTimer
    interval: Math.max(500, Number(root.interval) || 1000)
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.sampleFast()
  }

  Timer {
    id: temperatureTimer
    interval: 2000
    repeat: true
    running: root.cpuTempPath !== ""
    onTriggered: if (root.cpuTempPath !== "") tempFile.reload()
  }

  Timer {
    id: gpuTimer
    interval: Math.max(1000, Number(root.gpuInterval) || 2000)
    repeat: true
    running: root.gpuAvailable
    onTriggered: root.pollGpu()
  }

  Timer {
    id: processTimer
    interval: 2000
    repeat: true
    running: root.panelOpen
    onTriggered: root.refreshProcesses()
  }

  Timer {
    id: gpuProcessTimer
    interval: 5000
    repeat: true
    running: root.panelOpen && root.gpuPanelVisible
    onTriggered: if (root.gpuPanelVisible && root.gpuVendor === "nvidia" && !gpuApps.running) gpuApps.running = true
  }

  FileView {
    id: statFile
    path: "/proc/stat"
    watchChanges: false
    printErrors: false
    onLoaded: root.applyStat(text())
  }

  FileView {
    id: memFile
    path: "/proc/meminfo"
    watchChanges: false
    printErrors: false
    onLoaded: root.applyMemory(text())
  }

  FileView {
    id: freqFile
    path: "/proc/cpuinfo"
    watchChanges: false
    printErrors: false
    onLoaded: {
      root.cpuFrequency = Model.parseCpuFrequency(text())
      root.cpuName = Model.parseCpuModel(text())
    }
  }

  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    watchChanges: false
    printErrors: false
    onLoaded: root.uptime = Model.parseUptime(text())
  }

  FileView {
    id: tempFile
    path: root.cpuTempPath
    watchChanges: false
    printErrors: false
    onLoaded: root.cpuTemp = Model.parseTemperature(text())
  }

  Process {
    id: gpuProbe
    command: [
      "bash", "-c",
      "if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then echo nvidia; exit 0; fi; " +
      "for d in /sys/class/drm/card*/device; do [ -f \"$d/gpu_busy_percent\" ] && { echo amd; exit 0; }; done; echo none"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyGpuProbe(text)
    }
  }

  Process {
    id: gpuNvidia
    command: [
      "nvidia-smi",
      "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,driver_version",
      "--format=csv,noheader,nounits"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyNvidia(text)
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  Process {
    id: gpuAmd
    command: [
      "bash", "-c",
      "d=\"\"; for x in /sys/class/drm/card*/device; do [ -f \"$x/gpu_busy_percent\" ] && { d=\"$x\"; break; }; done; " +
      "[ -n \"$d\" ] || exit 1; " +
      "busy=$(cat \"$d/gpu_busy_percent\" 2>/dev/null || echo 0); " +
      "used=$(cat \"$d/mem_info_vram_used\" 2>/dev/null || echo 0); " +
      "total=$(cat \"$d/mem_info_vram_total\" 2>/dev/null || echo 0); " +
      "temp=-1; power=-1; " +
      "for h in \"$d\"/hwmon/hwmon*; do [ -f \"$h/temp1_input\" ] && { temp=$(( $(cat \"$h/temp1_input\") / 1000 )); break; }; done; " +
      "for h in \"$d\"/hwmon/hwmon*; do [ -f \"$h/power1_average\" ] && { power=$(( $(cat \"$h/power1_average\") / 1000000 )); break; }; done; " +
      "echo \"AMD Radeon,$busy,$used,$total,$temp,$power\""
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyAmd(text)
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  Process {
    id: processList
    command: ["ps", "-eo", "pid=,time=,rss=,comm="]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyProcessSnapshot(text)
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  Process {
    id: gpuApps
    command: ["nvidia-smi", "pmon", "-c", "1"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (root.panelOpen && root.gpuVendor === "nvidia") root.topGpu = Model.parseNvidiaProcesses(text)
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  function probeTemperature() {
    if (!tempProbe.running) tempProbe.running = true
  }

  Process {
    id: tempProbe
    command: [
      "bash", "-c",
      "for h in /sys/class/hwmon/hwmon*; do " +
      "n=$(cat \"$h/name\" 2>/dev/null) || continue; " +
      "case \"$n\" in coretemp|k10temp|zenpower|cpu_thermal) " +
      "[ -f \"$h/temp1_input\" ] && { echo \"$h/temp1_input\"; exit 0; };; esac; " +
      "done"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var path = String(text || "").trim().split("\n")[0]
        if (path !== "" && path.indexOf("/") === 0) {
          root.cpuTempPath = path
          tempFile.reload()
        }
      }
    }
  }
}
