import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Circular footer action. Only two are used (btop and settings), so this
// stays a small purpose-built control.
Item {
  id: root

  property string iconText: ""
  property string tooltipText: ""
  property bool active: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color background: Commons.Color.background
  signal clicked()

  implicitWidth: Style.space(38)
  implicitHeight: Style.space(38)

  readonly property bool hot: mouse.containsMouse

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: root.active
      ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
      : (root.hot ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10) : "transparent")
    border.width: Math.max(1, Style.space(1))
    border.color: root.active
      ? root.accent
      : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, root.hot ? 0.45 : 0.22)
    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 100 } }
  }

  Text {
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: root.iconText
    color: root.active ? root.accent : root.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.iconLarge
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  PanelToolTip {
    visible: mouse.containsMouse && root.tooltipText !== ""
    text: root.tooltipText
    fontFamily: Style.font.family
  }
}
