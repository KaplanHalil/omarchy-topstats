import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons

// Small line icons drawn as paths so they inherit the live theme color at any
// DPI. They are deliberately simple: TopHat's panel icons are recognizable
// silhouettes, not detailed illustrations, and the same rule holds at 16px.
Item {
  id: root

  property string kind: "cpu"
  property color color: Commons.Color.foreground
  property real strokeWidth: 1.15
  property real glyphSize: Style.space(16)

  implicitWidth: glyphSize
  implicitHeight: glyphSize

  function pathFor(value) {
    if (value === "gpu") {
      return "M1.5 4 H14.5 V11 H1.5 Z "
        + "M1.5 11 V13.5 H6 V11 "
        + "M9.5 4.9 a2.9 2.9 0 1 0 0.01 0 Z"
    }
    if (value === "ram") {
      return "M1.5 4.5 H14.5 V11 H1.5 Z "
        + "M6 11 V13 H10 V11 "
        + "M3.5 6 H5.2 V8.5 H3.5 Z "
        + "M6.6 6 H8.4 V8.5 H6.6 Z "
        + "M9.8 6 H11.6 V8.5 H9.8 Z "
        + "M3 13 V14.5 M5 13 V14.5 M7 13 V14.5 M9 13 V14.5 M11 13 V14.5 M13 13 V14.5"
    }
    // cpu
    return "M4 3 H12 A1 1 0 0 1 13 4 V12 A1 1 0 0 1 12 13 H4 A1 1 0 0 1 3 12 V4 A1 1 0 0 1 4 3 Z "
      + "M6 6 H10 V10 H6 Z "
      + "M5 1 V3 M8 1 V3 M11 1 V3 "
      + "M5 13 V15 M8 13 V15 M11 13 V15 "
      + "M1 5 H3 M1 8 H3 M1 11 H3 "
      + "M13 5 H15 M13 8 H15 M13 11 H15"
  }

  Shape {
    anchors.fill: parent

    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeWidth
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.pathFor(root.kind) }
    }
  }
}
