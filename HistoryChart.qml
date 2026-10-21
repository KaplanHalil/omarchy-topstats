import QtQuick
import qs.Commons
import qs.Commons as Commons

// History chart: a quiet dark well, thin accent bars, a percentage
// scale on the right, and "2 mins ago / now" beneath. The canvas is redrawn
// only when the sampler publishes a new history array, not on every frame.
Item {
  id: root

  property var values: []
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  property string startLabel: "2 mins ago"
  property string endLabel: "now"
  property int slots: 120

  implicitHeight: chart.height + Style.space(4) + footer.implicitHeight

  onValuesChanged: canvas.requestPaint()
  onAccentChanged: canvas.requestPaint()
  onSlotsChanged: canvas.requestPaint()
  Component.onCompleted: canvas.requestPaint()

  readonly property color dim: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.62)
  readonly property color well: Qt.rgba(0, 0, 0, 0.20)

  Item {
    id: chart
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Style.space(96)

    Rectangle {
      anchors.fill: parent
      radius: Style.space(4)
      color: root.well
    }

    Canvas {
      id: canvas
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: scaleLabels.left
      anchors.leftMargin: Style.space(4)
      anchors.rightMargin: Style.space(4)
      anchors.topMargin: Style.space(4)
      anchors.bottomMargin: Style.space(4)

      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var data = root.values || []
        if (data.length === 0) return
        var slots = Math.max(data.length, root.slots || 120)
        var slotWidth = width / slots
        var gap = Math.min(1, slotWidth * 0.25)
        var barWidth = Math.max(1, slotWidth - gap)
        var color = "rgba(" + Math.round(root.accent.r * 255) + ","
          + Math.round(root.accent.g * 255) + ","
          + Math.round(root.accent.b * 255) + ","
          + Math.round(root.accent.a * 100) / 100 + ")"
        ctx.fillStyle = color
        var startX = width - data.length * slotWidth
        for (var i = 0; i < data.length; i++) {
          var value = Math.max(0, Math.min(100, Number(data[i]) || 0))
          var barHeight = Math.max(1, height * value / 100)
          var x = startX + i * slotWidth
          ctx.fillRect(x, height - barHeight, barWidth, barHeight)
        }
      }

      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
    }

    Text {
      anchors.centerIn: parent
      visible: !root.values || root.values.length === 0
      text: "Collecting…"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Item {
      id: scaleLabels
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.rightMargin: Style.space(4)
      width: Style.space(30)

      Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: "100%"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "50%"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: "0%"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Item {
    id: footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: chart.bottom
    anchors.topMargin: Style.space(4)
    implicitHeight: footerLeft.implicitHeight

    Text {
      id: footerLeft
      anchors.left: parent.left
      text: root.startLabel
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      anchors.right: parent.right
      text: root.endLabel
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
