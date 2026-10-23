import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// TopStats bar widget: a single compact group for CPU, GPU, RAM and network.
// Left click opens the details panel on that metric, right click opens btop.
BarWidget {
  id: root
  moduleName: "io.github.kaplanhalil.topstats"

  property string lastMetric: "cpu"

  readonly property bool showCpuValue: boolSetting("showCpuValue", boolSetting("showValues", true))
  readonly property bool showGpuValue: boolSetting("showGpuValue", boolSetting("showValues", true))
  readonly property bool showRamValue: boolSetting("showRamValue", boolSetting("showValues", true))
  readonly property string cpuStyle: String(setting("cpuStyle", "cores"))
  readonly property bool showGpu: boolSetting("showGpu", true)
  readonly property bool showNetwork: boolSetting("showNetwork", true)
  readonly property var foregroundColor: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool gpuVisible: root.showGpu && sampler.gpuAvailable
  readonly property bool netVisible: root.showNetwork && !root.vertical && sampler.netAvailable
  readonly property int segmentCount: 2 + (root.gpuVisible ? 1 : 0) + (root.netVisible ? 1 : 0)

  function ramFraction() {
    var totalGiB = sampler.memory.total / (1024 * 1024 * 1024)
    if (!isFinite(totalGiB) || totalGiB <= 0) return "—"
    var usedGiB = sampler.memory.used / (1024 * 1024 * 1024)
    var usedText = usedGiB.toFixed(1).replace(/\.0$/, "")
    return usedText + "/" + Math.round(totalGiB)
  }

  function boolSetting(name, fallback) {
    var value = setting(name, fallback)
    if (value === true || value === 1) return true
    if (value === false || value === 0) return false
    var text = String(value).toLowerCase()
    if (text === "true" || text === "yes" || text === "on" || text === "1") return true
    if (text === "false" || text === "no" || text === "off" || text === "0") return false
    return fallback
  }

  function cpuTooltip() {
    var parts = ["CPU " + Model.formatPercent(sampler.cpuPercent)]
    if (sampler.cpuFrequency > 0) parts.push(Model.formatFrequency(sampler.cpuFrequency))
    if (sampler.cpuTemp >= 0) parts.push(Model.formatTemperature(sampler.cpuTemp))
    return parts.join(" · ")
  }

  function gpuTooltip() {
    var parts = [sampler.gpuName || "GPU"]
    parts.push(Model.formatPercent(sampler.gpuPercent))
    if (sampler.gpuMemTotal > 0)
      parts.push(Model.formatBytes(sampler.gpuMemUsed) + " / " + Model.formatBytes(sampler.gpuMemTotal))
    if (sampler.gpuTemp >= 0) parts.push(Model.formatTemperature(sampler.gpuTemp))
    if (sampler.gpuPower >= 0) parts.push(Model.formatPower(sampler.gpuPower))
    return parts.join(" · ")
  }

  function memoryTooltip() {
    var parts = ["RAM " + Model.formatPercent(sampler.memory.percent)]
    parts.push(Model.formatBytes(sampler.memory.used) + " / " + Model.formatBytes(sampler.memory.total))
    if (sampler.memory.swapTotal > 0)
      parts.push("swap " + Model.formatPercent(sampler.memory.swapPercent))
    return parts.join(" · ")
  }

  function openMetric(metric) {
    lastMetric = metric
    if (panelLoader.item) panelLoader.item.openFor(metric)
    else Qt.callLater(function() { root.openMetric(metric) })
  }

  function open() { openMetric(lastMetric) }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { opened ? close() : open() }

  function handleSegment(metric, button) {
    if (button === Qt.RightButton) {
      if (bar) bar.run("omarchy-launch-or-focus-tui btop")
      return
    }
    openMetric(metric)
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  onOpenedChanged: if (sampler) sampler.setPanelOpen(opened)

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: root.vertical ? (bar ? bar.barSize : Style.bar.sizeVertical) : layout.implicitWidth + Style.space(12)
  implicitHeight: root.vertical ? layout.implicitHeight + Style.space(4) : (bar ? bar.barSize : Style.bar.sizeHorizontal)

  Sampler {
    id: sampler
    interval: Math.max(500, Number(root.setting("interval", 1000)) || 1000)
    gpuInterval: Math.max(1000, Number(root.setting("gpuInterval", 2000)) || 2000)
    gpuMode: String(root.setting("gpuDevice", "auto"))
    networkEnabled: root.showNetwork
  }

  Grid {
    id: layout
    anchors.centerIn: parent
    columns: root.vertical ? 1 : root.segmentCount
    flow: Grid.LeftToRight
    spacing: root.vertical ? Style.space(1) : Style.space(7)

    BarSegment {
      id: cpuSegment
      bar: root.bar
      vertical: root.vertical
      label: "CPU"
      value: sampler.cpuPercent
      coresMode: root.cpuStyle === "cores"
      cores: sampler.cpuCores
      showValue: root.showCpuValue
      foreground: root.foregroundColor
      urgent: bar ? bar.urgent : Commons.Color.urgent
      tooltipText: root.cpuTooltip()
      onClicked: function(button) { root.handleSegment("cpu", button) }
    }

    BarSegment {
      id: gpuSegment
      visible: root.showGpu && sampler.gpuAvailable
      bar: root.bar
      vertical: root.vertical
      label: "GPU"
      value: sampler.gpuPercent
      showValue: root.showGpuValue
      foreground: root.foregroundColor
      urgent: bar ? bar.urgent : Commons.Color.urgent
      tooltipText: root.gpuTooltip()
      onClicked: function(button) { root.handleSegment("gpu", button) }
    }

    BarSegment {
      id: memorySegment
      bar: root.bar
      vertical: root.vertical
      label: "RAM"
      value: sampler.memory.percent
      displayText: root.ramFraction()
      valueWidth: Style.space(50)
      showValue: root.showRamValue
      foreground: root.foregroundColor
      urgent: bar ? bar.urgent : Commons.Color.urgent
      tooltipText: root.memoryTooltip()
      onClicked: function(button) { root.handleSegment("ram", button) }
    }

    NetSegment {
      id: networkSegment
      visible: root.netVisible
      bar: root.bar
      rxRate: sampler.netRxRate
      txRate: sampler.netTxRate
      interfaces: sampler.netInterfaces
      foreground: root.foregroundColor
      accent: Commons.Color.accent
      onClicked: function(button) { root.handleSegment("net", button) }
    }
  }

  Loader {
    id: panelLoader
    active: true
    visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = layout
    if ("hostWidget" in target) target.hostWidget = root
    if ("sampler" in target) target.sampler = sampler
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  IpcHandler {
    target: root.moduleName

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function cpu(): void { root.openMetric("cpu") }
    function gpu(): void { root.openMetric("gpu") }
    function ram(): void { root.openMetric("ram") }
    function net(): void { root.openMetric("net") }
    function settings(): void {
      if (!panelLoader.item) return
      panelLoader.item.openFor(root.lastMetric)
      panelLoader.item.settingsMode = true
    }
  }}
