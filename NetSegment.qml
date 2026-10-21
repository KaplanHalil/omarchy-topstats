import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// Compact network segment: two tiny lines under a NET label, no meter.
// The wide version with arrows on one line would steal too much bar space;
// stacking them keeps the fourth segment close to the width of GPU/RAM.
Item {
  id: root

  property var bar: null
  property real rxRate: 0
  property real txRate: 0
  property string interfaces: ""
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  readonly property real arrowWidth: Style.space(8)
  readonly property real rateWidth: Style.space(38)

  signal clicked(int button)

  readonly property bool hot: mouse.containsMouse
  readonly property string styleFont: bar && bar.fontFamily ? bar.fontFamily : Style.font.family
  readonly property string tooltipText: {
    var text = "NET · ↓ " + Model.formatRate(rxRate) + " · ↑ " + Model.formatRate(txRate)
    if (interfaces) text += " · " + interfaces
    return text
  }

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

  implicitWidth: Style.space(86)
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
    spacing: Style.space(4)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "NET"
      color: root.foreground
      font.family: root.styleFont
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      font.letterSpacing: 0.5
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0

      Row {
        spacing: Style.space(2)
        Text {
          width: root.arrowWidth
          horizontalAlignment: Text.AlignHCenter
          text: "↓"
          color: root.accent
          font.family: root.styleFont
          font.pixelSize: Style.font.caption
        }
        Text {
          width: root.rateWidth
          horizontalAlignment: Text.AlignRight
          text: Model.formatRateCompact(root.rxRate)
          color: root.foreground
          font.family: root.styleFont
          font.pixelSize: Style.font.caption
        }
      }

      Row {
        spacing: Style.space(2)
        Text {
          width: root.arrowWidth
          horizontalAlignment: Text.AlignHCenter
          text: "↑"
          color: root.accent
          font.family: root.styleFont
          font.pixelSize: Style.font.caption
        }
        Text {
          width: root.rateWidth
          horizontalAlignment: Text.AlignRight
          text: Model.formatRateCompact(root.txRate)
          color: root.foreground
          font.family: root.styleFont
          font.pixelSize: Style.font.caption
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
}
