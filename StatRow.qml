import QtQuick
import qs.Commons
import qs.Commons as Commons

// A label/value row in the TopHat details card. Values are right-aligned and
// slightly heavier so the eye can scan the numbers without reading the labels.
Item {
  id: root

  property string label: ""
  property string value: ""
  property bool detail: false
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  readonly property color dim: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.58)

  implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)
  implicitWidth: Style.space(200)

  Text {
    id: labelText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: root.label
    color: root.detail ? root.dim : root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.detail ? Style.font.bodySmall : Style.font.body
    elide: Text.ElideRight
    width: Math.max(0, parent.width - valueText.implicitWidth - Style.space(12))
  }

  Text {
    id: valueText
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: root.value
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.detail ? Style.font.bodySmall : Style.font.body
    font.bold: !root.detail
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideLeft
  }
}
