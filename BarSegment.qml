import QtQuick
import qs.Commons
import qs.Commons as Commons

// One TopHat-style metric: label, optional percentage, and a compact meter.
// The meter is either a single vertical fill or a row of per-core bars.
Item {
  id: root

  property var bar: null
  property string label: ""
  property bool vertical: false
  property bool showValue: true
  property string displayText: ""
  property real valueWidth: Style.space(30)
  property bool coresMode: false
  property var cores: []
  property real value: 0
  property color foreground: Commons.Color.foreground
  property color urgent: Commons.Color.urgent
  property color warning: "#e0af68"
  property string tooltipText: ""

  signal clicked(int button)

  // The bar forwards clicks that fall on its strip while a panel is open
  // through registered targets. Exposing the same triggerPress contract as
  // WidgetButton keeps switching between metrics working in one click.
  function triggerPress(button) { root.clicked(button) }
  function syncClickRegistration() {
    if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(root)
    registeredBar = root.bar
    if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(root)
  }

  property var registeredBar: null
  onBarChanged: syncClickRegistration()
  Component.onCompleted: syncClickRegistration()
  Component.onDestruction: if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(root)

  readonly property bool hot: mouse.containsMouse
  readonly property bool critical: value >= 75
  readonly property real meterWidth: vertical ? Style.space(5) : Style.space(6)
  readonly property real meterHeight: vertical ? Style.space(14) : Style.space(16)
  readonly property real coreTrackHeight: Style.space(18)
  readonly property real coreBarWidth: Math.max(2, Style.space(3))
  readonly property real coreGap: Math.max(1, Style.space(1))
  readonly property real coreTrackWidth: Math.max(
    Style.space(34),
    cores.length * coreBarWidth + Math.max(0, cores.length - 1) * coreGap + Style.space(4)
  )

  // White -> amber -> theme red. The component is shared by CPU, GPU, and
  // RAM, so all three follow the same thresholds.
  function levelColor(load) {
    var n = Number(load)
    if (!isFinite(n)) return foreground
    if (n >= 75) return urgent
    if (n >= 50) return warning
    return foreground
  }

  readonly property color valueColor: levelColor(value)

  implicitWidth: content.implicitWidth + Style.space(vertical ? 3 : 7) * 2
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  Rectangle {
    anchors.fill: parent
    radius: Style.space(3)
    color: root.hot ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.09) : "transparent"
    Behavior on color { ColorAnimation { duration: 90 } }
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(vertical ? 3 : 4)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: root.vertical ? root.label.charAt(0) : root.label
      color: root.foreground
      font.family: styleFont
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      font.letterSpacing: 0.5
    }

      Text {
        visible: root.showValue && !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        width: root.valueWidth
        textFormat: Text.PlainText
        text: root.displayText !== "" ? root.displayText : (root.value < 0 ? "—" : Math.round(root.value) + "%")
        horizontalAlignment: Text.AlignRight
        color: root.valueColor
        font.family: styleFont
        font.pixelSize: Style.font.bodySmall
        font.bold: root.critical
      }

    // Single value meter, TopHat's default: a translucent 1.3em track with a
    // fill growing from the bottom.
    Item {
      visible: !root.coresMode || root.vertical
      anchors.verticalCenter: parent.verticalCenter
      width: root.meterWidth
      height: root.meterHeight

      Rectangle {
        anchors.fill: parent
        radius: Style.space(2)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
      }

      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.max(1, parent.height * Math.max(0, Math.min(100, root.value)) / 100)
        radius: Style.space(2)
        color: root.valueColor
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 160 } }
      }
    }

    // Per-core mode. At 3px + 1px gap a 24-thread CPU takes about 99px, so it
    // still fits beside the percentage without swallowing the bar.
    Rectangle {
      visible: root.coresMode && !root.vertical
      anchors.verticalCenter: parent.verticalCenter
      width: root.coreTrackWidth
      height: root.coreTrackHeight
      radius: Style.space(2)
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)

      Row {
        anchors.fill: parent
        anchors.margins: Style.space(2)
        spacing: root.coreGap

        Repeater {
          model: root.cores.length

          Item {
            required property int index
            width: root.coreBarWidth
            height: parent.height

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: Math.max(1, parent.height * Math.max(0, Math.min(100, Number(root.cores[index]) || 0)) / 100)
              radius: Style.space(1)
              color: root.levelColor(Number(root.cores[index]) || 0)
            }
          }
        }
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.bar && root.tooltipText !== "") root.bar.showTooltip(root, root.tooltipText)
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: function(event) { root.clicked(event.button) }
  }

  // The bar owns the font family; a bare preview (qmllint, design harness)
  // still gets the shell's monospace default.
  readonly property string styleFont: bar && bar.fontFamily ? bar.fontFamily : Style.font.family
}
