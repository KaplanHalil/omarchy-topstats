import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// "Top processes" section used by all three tabs. Keeping the header and the
// empty state here means the three pages stay short and consistent.
Item {
  id: root

  property string title: "Top processes"
  property var rows: []
  property string mode: "cpu"
  property string emptyText: "Collecting…"
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  implicitHeight: sectionColumn.implicitHeight

  function rowValue(row) {
    if (root.mode === "mem") return Model.formatBytes(row.memory)
    if (root.mode === "gpu") return Model.formatPercent(row.gpu)
    return Model.formatPercent(row.cpu)
  }

  Column {
    id: sectionColumn
    width: parent.width
    spacing: Style.space(2)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.title
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      topPadding: Style.space(6)
      bottomPadding: Style.space(2)
    }

    Repeater {
      model: root.rows

      ProcessRow {
        required property var modelData
        width: sectionColumn.width
        name: modelData.name
        value: root.rowValue(modelData)
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }

    Text {
      width: parent.width
      visible: !root.rows || root.rows.length === 0
      textFormat: Text.PlainText
      text: root.emptyText
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.58)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
      topPadding: Style.space(2)
    }
  }
}
