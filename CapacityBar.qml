import QtQuick
import qs.Commons
import qs.Commons as Commons

// TopHat's capacity rule: a quiet track with a single accent fill. It is
// deliberately thinner than the history chart so the panel reads as
// headline -> capacity -> trend.
Item {
  id: root

  property real value: 0
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
  readonly property bool critical: value >= 90

  implicitHeight: Style.space(5)
  implicitWidth: Style.space(120)

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
  }

  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Math.max(0, parent.width * Math.max(0, Math.min(100, root.value)) / 100)
    radius: height / 2
    color: root.critical ? root.urgent : root.accent
    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 160 } }
  }
}
