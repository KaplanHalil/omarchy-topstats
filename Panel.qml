import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Details card for the TopStats bar group. The card follows the shell theme
// (surface, accent, corner radius, font) and uses a centered heading,
// label/value rows, a quiet history chart, top applications, and round actions.
Panel {
  id: root
  moduleName: "io.github.kaplanhalil.topstats"
  readonly property string coffeeUrl: "https://buymeacoffee.com/kaplanhalil"
  ipcTarget: ""
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var sampler: null

  property string tab: "cpu"
  property bool settingsMode: false

  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: Commons.Color.urgent
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.58)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var tabs: {
    var out = [{ id: "cpu", label: "CPU" }]
    if (sampler && sampler.gpuAvailable) out.push({ id: "gpu", label: "GPU" })
    out.push({ id: "ram", label: "RAM" })
    if (sampler && sampler.netAvailable && showNetworkSetting) out.push({ id: "net", label: "NET" })
    return out
  }

  readonly property string heading: settingsMode
    ? "TopStats settings"
    : (tab === "gpu" ? "Graphics usage" : tab === "ram" ? "Memory usage" : tab === "net" ? "Network activity" : "Processor usage")

  readonly property bool showCpuValueSetting: boolSetting("showCpuValue", boolSetting("showValues", true))
  readonly property bool showGpuValueSetting: boolSetting("showGpuValue", boolSetting("showValues", true))
  readonly property bool showRamValueSetting: boolSetting("showRamValue", boolSetting("showValues", true))
  readonly property bool showNetworkSetting: boolSetting("showNetwork", true)
  readonly property string cpuStyleSetting: String(setting("cpuStyle", "cores"))
  readonly property bool gpuEnabledSetting: String(setting("gpuDevice", "auto")) !== "off"
  readonly property int intervalSetting: Math.max(500, Number(setting("interval", 1000)) || 1000)
  readonly property int gpuIntervalSetting: Math.max(1000, Number(setting("gpuInterval", 2000)) || 2000)

  function boolSetting(name, fallback) {
    var value = setting(name, fallback)
    if (value === true || value === 1) return true
    if (value === false || value === 0) return false
    var text = String(value).toLowerCase()
    if (text === "true" || text === "yes" || text === "on" || text === "1") return true
    if (text === "false" || text === "no" || text === "off" || text === "0") return false
    return fallback
  }

  function openFor(metric) {
    if (metric === "gpu" && !(sampler && sampler.gpuAvailable)) metric = "cpu"
    if (metric === "net" && !(sampler && sampler.netAvailable && showNetworkSetting)) metric = "cpu"
    tab = metric
    settingsMode = false
    if (!opened) controller.show()
    if (sampler) sampler.setPanelOpen(true)
    syncGpuPanel()
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function syncGpuPanel() {
    if (!sampler) return
    sampler.setGpuPanelVisible(opened && !settingsMode && tab === "gpu")
  }

  onTabChanged: syncGpuPanel()
  onSettingsModeChanged: syncGpuPanel()
  onOpenedChanged: syncGpuPanel()
  onShowNetworkSettingChanged: if (!showNetworkSetting && tab === "net") tab = "cpu"

  function open() {
    openFor(tab)
  }

  function close() {
    controller.hide()
    if (sampler) sampler.setPanelOpen(false)
  }

  function switchTab(direction) {
    if (settingsMode) return
    var current = 0
    for (var i = 0; i < tabs.length; i++) if (tabs[i].id === tab) current = i
    var next = (current + direction + tabs.length) % tabs.length
    tab = tabs[next].id
  }

  function persist(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function formatPercent(value) { return Model.formatPercent(value) }
  function formatBytes(value) { return Model.formatBytes(value) }
  function formatTemperature(value) { return Model.formatTemperature(value) }
  function formatFrequency(value) { return Model.formatFrequency(value) }
  function formatPower(value) { return Model.formatPower(value) }
  function formatUptime(value) { return Model.formatUptime(value) }
  function formatRate(value) { return Model.formatRate(value) }
  function formatCount(value) {
    var n = Number(value)
    return isFinite(n) ? String(Math.round(n)) : "—"
  }

  Connections {
    target: root.sampler
    function onGpuAvailableChanged() {
      if (!root.sampler || !root.sampler.gpuAvailable) {
        if (root.tab === "gpu") root.tab = "cpu"
      }
    }
  }

  KeyboardPanel {
    id: keyboard
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: keyboard.fittedContentWidth(Style.space(410))
    contentHeight: keyboard.fittedContentHeight(contentColumn.implicitHeight, Style.space(660))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.switchTab(dx)
        if (dy !== 0) {
          flick.contentY = Math.max(0, Math.min(
            flick.contentHeight - flick.height,
            flick.contentY + dy * Style.space(58)
          ))
        }
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchTab(direction) }
      onTextKey: function(text) {
        if (text === "s" || text === "S") root.settingsMode = !root.settingsMode
        else if (text === "r" || text === "R") { if (root.sampler) root.sampler.refreshProcesses() }
        else if (text === "1") root.tab = "cpu"
        else if (text === "2" && root.sampler && root.sampler.gpuAvailable) root.tab = "gpu"
        else if (text === "3") root.tab = "ram"
        else if (text === "4" && root.sampler && root.sampler.netAvailable && root.showNetworkSetting) root.tab = "net"
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: flick.width
          spacing: Style.space(9)

          // ---------- Heading and tabs ----------
          Item {
            width: parent.width
            implicitHeight: headingColumn.implicitHeight

            Column {
              id: headingColumn
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(2)

              Text {
                width: Style.space(320)
                textFormat: Text.PlainText
                text: root.heading
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
              }

              Row {
                visible: !root.settingsMode
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(16)

                Repeater {
                  model: root.tabs

                  Item {
                    required property var modelData
                    width: tabLabel.implicitWidth + Style.space(10)
                    height: Style.space(26)

                    readonly property bool active: root.tab === modelData.id

                    Text {
                      id: tabLabel
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: modelData.label
                      color: parent.active ? root.accent : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: parent.active
                    }

                    Rectangle {
                      anchors.bottom: parent.bottom
                      anchors.horizontalCenter: parent.horizontalCenter
                      width: parent.width
                      height: Style.space(2)
                      radius: height / 2
                      color: root.accent
                      visible: parent.active
                    }

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.tab = modelData.id
                        root.settingsMode = false
                      }
                    }
                  }
                }
              }
            }
          }

          // ---------- CPU ----------
          Column {
            visible: !root.settingsMode && root.tab === "cpu"
            width: parent.width
            spacing: Style.space(7)

            StatRow {
              width: parent.width
              label: "Processor utilization:"
              value: root.sampler ? root.formatPercent(root.sampler.cpuPercent) : "—"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            CapacityBar {
              width: parent.width
              value: root.sampler ? root.sampler.cpuPercent : 0
              foreground: root.foreground
              accent: root.accent
              urgent: root.urgent
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.sampler ? root.sampler.cpuName : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            StatRow {
              width: parent.width
              label: "Frequency:"
              value: root.sampler ? root.formatFrequency(root.sampler.cpuFrequency) : "—"
              detail: true
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            StatRow {
              width: parent.width
              label: "Temperature:"
              value: root.sampler ? root.formatTemperature(root.sampler.cpuTemp) : "—"
              detail: true
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            HistoryChart {
              width: parent.width
              values: root.sampler ? root.sampler.cpuHistory : []
              slots: root.sampler ? root.sampler.historyLimit : 120
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
            }

            ProcessSection {
              width: parent.width
              title: "Top applications"
              rows: root.sampler ? root.sampler.topAppsCpu : []
              mode: "cpu"
              emptyText: "Collecting…"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            UptimeBlock {
              width: parent.width
              seconds: root.sampler ? root.sampler.uptime : 0
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
          }

          // ---------- GPU ----------
          Column {
            visible: !root.settingsMode && root.tab === "gpu" && root.sampler && root.sampler.gpuAvailable
            width: parent.width
            spacing: Style.space(7)

            StatRow {
              width: parent.width
              label: "GPU utilization:"
              value: root.sampler ? root.formatPercent(root.sampler.gpuPercent) : "—"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            CapacityBar {
              width: parent.width
              value: root.sampler ? root.sampler.gpuPercent : 0
              foreground: root.foreground
              accent: root.accent
              urgent: root.urgent
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.sampler ? (root.sampler.gpuName + (root.sampler.gpuDriver ? " · " + root.sampler.gpuDriver : "")) : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            StatRow {
              width: parent.width
              label: "VRAM used:"
              value: root.sampler
                ? root.formatBytes(root.sampler.gpuMemUsed) + " / " + root.formatBytes(root.sampler.gpuMemTotal)
                : "—"
              detail: true
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            StatRow {
              width: parent.width
              label: "Temperature:"
              value: root.sampler ? root.formatTemperature(root.sampler.gpuTemp) : "—"
              detail: true
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            StatRow {
              width: parent.width
              label: "Power draw:"
              value: root.sampler ? root.formatPower(root.sampler.gpuPower) : "—"
              detail: true
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            HistoryChart {
              width: parent.width
              values: root.sampler ? root.sampler.gpuHistory : []
              slots: root.sampler ? root.sampler.gpuHistoryLimit : 60
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
            }

            ProcessSection {
              width: parent.width
              title: "Top GPU applications"
              rows: root.sampler ? root.sampler.topGpu : []
              mode: "gpu"
              emptyText: root.sampler && root.sampler.gpuVendor === "amd"
                ? "Per-process GPU usage is unavailable on amdgpu"
                : "No GPU activity"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
          }

          // ---------- RAM ----------
          Column {
            visible: !root.settingsMode && root.tab === "ram"
            width: parent.width
            spacing: Style.space(7)

            StatRow {
              width: parent.width
              label: "RAM used:"
              value: root.sampler ? root.formatPercent(root.sampler.memory.percent) : "—"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.sampler
                ? root.formatBytes(root.sampler.memory.available) + " available of " + root.formatBytes(root.sampler.memory.total)
                : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignRight
            }

            CapacityBar {
              width: parent.width
              value: root.sampler ? root.sampler.memory.percent : 0
              foreground: root.foreground
              accent: root.accent
              urgent: root.urgent
            }

            StatRow {
              width: parent.width
              label: "Swap used:"
              value: root.sampler ? root.formatPercent(root.sampler.memory.swapPercent) : "—"
              detail: true
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.sampler && root.sampler.memory.swapTotal > 0
                ? root.formatBytes(root.sampler.memory.swapUsed) + " of " + root.formatBytes(root.sampler.memory.swapTotal)
                : "No swap configured"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignRight
            }

            CapacityBar {
              width: parent.width
              value: root.sampler ? root.sampler.memory.swapPercent : 0
              foreground: root.foreground
              accent: root.accent
              urgent: root.urgent
            }

            HistoryChart {
              width: parent.width
              values: root.sampler ? root.sampler.memoryHistory : []
              slots: root.sampler ? root.sampler.historyLimit : 120
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
            }

            ProcessSection {
              width: parent.width
              title: "Top applications"
              rows: root.sampler ? root.sampler.topAppsRam : []
              mode: "mem"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            UptimeBlock {
              width: parent.width
              seconds: root.sampler ? root.sampler.uptime : 0
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
          }

          // ---------- Network ----------
          Column {
            visible: !root.settingsMode && root.tab === "net" && root.sampler && root.sampler.netAvailable
            width: parent.width
            spacing: Style.space(7)

            StatRow {
              width: parent.width
              label: "Download:"
              value: root.sampler ? root.formatRate(root.sampler.netRxRate) : "—"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            StatRow {
              width: parent.width
              label: "Upload:"
              value: root.sampler ? root.formatRate(root.sampler.netTxRate) : "—"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            StatRow {
              width: parent.width
              label: "Received:"
              value: root.sampler ? root.formatBytes(root.sampler.netRxTotal) : "—"
              detail: true
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            StatRow {
              width: parent.width
              label: "Sent:"
              value: root.sampler ? root.formatBytes(root.sampler.netTxTotal) : "—"
              detail: true
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            StatRow {
              width: parent.width
              label: "Interface:"
              value: root.sampler && root.sampler.netInterfaces !== "" ? root.sampler.netInterfaces : "—"
              detail: true
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "Received and sent counters are since boot."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              topPadding: Style.space(4)
            }
          }

          // ---------- Settings ----------
          Column {
            visible: root.settingsMode
            width: parent.width
            spacing: Style.space(8)

            Toggle {
              width: parent.width
              label: "CPU percentage"
              description: "Show CPU load in the bar"
              checked: root.showCpuValueSetting
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.persist({ showCpuValue: !root.showCpuValueSetting })
            }

            Toggle {
              width: parent.width
              label: "GPU percentage"
              description: "Show GPU load in the bar"
              checked: root.showGpuValueSetting
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.persist({ showGpuValue: !root.showGpuValueSetting })
            }

            Toggle {
              width: parent.width
              label: "RAM used/total"
              description: "Show used and total GiB in the bar"
              checked: root.showRamValueSetting
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.persist({ showRamValue: !root.showRamValueSetting })
            }

            Toggle {
              width: parent.width
              label: "CPU core bars"
              description: "One mini bar per logical CPU"
              checked: root.cpuStyleSetting === "cores"
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.persist({ cpuStyle: root.cpuStyleSetting === "cores" ? "meter" : "cores" })
            }

            Toggle {
              width: parent.width
              label: "Monitor GPU"
              description: "NVIDIA via nvidia-smi, AMD via sysfs"
              checked: root.gpuEnabledSetting
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.persist({ gpuDevice: root.gpuEnabledSetting ? "off" : "auto" })
            }

            Toggle {
              width: parent.width
              label: "Network speed"
              description: "Upload/download rates in the bar"
              checked: root.showNetworkSetting
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.persist({ showNetwork: !root.showNetworkSetting })
            }

            Item { width: 1; height: Style.space(2) }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "Update interval"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            ButtonGroup {
              width: parent.width
              options: [
                { value: "1000", label: "1 s" },
                { value: "2000", label: "2 s" },
                { value: "5000", label: "5 s" }
              ]
              value: String(root.intervalSetting)
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              focusable: false
              onChanged: function(value) { root.persist({ interval: Number(value) }) }
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "Shorter CPU/RAM intervals add samples to the 2-minute history."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "GPU interval"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              topPadding: Style.space(4)
            }

            ButtonGroup {
              width: parent.width
              options: [
                { value: "2000", label: "2 s" },
                { value: "5000", label: "5 s" },
                { value: "10000", label: "10 s" }
              ]
              value: String(root.gpuIntervalSetting)
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              focusable: false
              onChanged: function(value) { root.persist({ gpuInterval: Number(value) }) }
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "Every nvidia-smi poll briefly wakes the card. 2 s is responsive; 5–10 s saves more idle power."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Button {
              text: "Done"
              bordered: true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.settingsMode = false
            }
          }

          // ---------- Footer actions ----------
          Item {
            width: parent.width
            height: Style.space(50)

            Row {
              anchors.centerIn: parent
              spacing: Style.space(14)

              RoundAction {
                iconText: "\uf120"
                tooltipText: "Open btop"
                foreground: root.foreground
                accent: root.accent
                onClicked: if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
              }

              RoundAction {
                iconText: "\uf013"
                tooltipText: root.settingsMode ? "Back to stats" : "TopStats settings"
                active: root.settingsMode
                foreground: root.foreground
                accent: root.accent
                onClicked: root.settingsMode = !root.settingsMode
              }

              RoundAction {
                iconText: "\uf0f4"
                tooltipText: "Buy me a coffee"
                foreground: root.foreground
                accent: root.accent
                onClicked: Qt.openUrlExternally(root.coffeeUrl)
              }
            }
          }
        }
      }
    }
  }
}
