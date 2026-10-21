import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// Centered uptime block, mirroring TopHat's quiet closing note.
Item {
  id: root

  property real seconds: 0
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  implicitHeight: column.implicitHeight

  Column {
    id: column
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.space(1)

    Text {
      width: Style.space(220)
      textFormat: Text.PlainText
      text: "System uptime"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      topPadding: Style.space(6)
    }

    Text {
      width: Style.space(220)
      textFormat: Text.PlainText
      text: Model.formatUptime(root.seconds)
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.68)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
