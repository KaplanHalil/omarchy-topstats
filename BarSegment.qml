import QtQuick
import qs.Commons
import qs.Commons as Commons

// One TopHat-style metric: icon, optional percentage, and a compact meter.
// The meter is either a single vertical fill or a row of per-core bars.
Item {
  id: root

  property var bar: null
  property string iconKind: "cpu"
  property bool vertical: false
  property bool showValue: true
  property bool coresMode: false
  property var cores: []
  property real value: 0
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
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
  readonly property bool critical: value >= 90
  readonly property color stateColor: critical ? urgent : accent
  readonly property real glyphSize: vertical ? Style.space(13) : Style.space(15)
  readonly property real meterWidth: vertical ? Style.space(5) : Style.space(6)
  readonly property real meterHeight: vertical ? Style.space(14) : Style.space(16)
  readonly property int coreBarWidth: 2
  readonly property int coreGap: 1
  readonly property real coreTrackWidth: Math.max(
    Style.space(34),
    cores.length * coreBarWidth + Math.max(0, cores.length - 1) * coreGap + Style.space(4)
  )

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

    Icon {
      anchors.verticalCenter: parent.verticalCenter
      kind: root.iconKind
      color: root.critical ? root.urgent : root.foreground
      glyphSize: root.glyphSize
      strokeWidth: 1.1
    }

    Text {
      visible: root.showValue && !root.vertical
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(29)
      textFormat: Text.PlainText
      text: root.value < 0 ? "—" : Math.round(root.value) + "%"
      horizontalAlignment: Text.AlignRight
      color: root.critical ? root.urgent : root.foreground
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
        color: root.stateColor
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 160 } }
      }
    }

    // Per-core mode. A 24-thread CPU still fits in roughly 70px, which is
    // why this stays usable in a bar that already has a tray.
    Rectangle {
      visible: root.coresMode && !root.vertical
      anchors.verticalCenter: parent.verticalCenter
      width: root.coreTrackWidth
      height: root.meterHeight
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
              color: root.stateColor
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
