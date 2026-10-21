import QtQuick
import qs.Commons
import qs.Commons as Commons

// One row in the TopHat process table: name on the left, metric on the right.
Item {
  id: root

  property string name: ""
  property string value: ""
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  implicitHeight: Style.space(20)
  implicitWidth: Style.space(180)

  Text {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, parent.width - valueText.implicitWidth - Style.space(10))
    textFormat: Text.PlainText
    text: root.name
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Text {
    id: valueText
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: root.value
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: true
  }
}
