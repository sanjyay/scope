// LoadingDots — animated three-dot loading indicator.
// Minimal, non-blocking. Dots pulse with staggered delays.

import QtQuick

Row {
  id: root
  spacing: 5

  Repeater {
    model: 3

    Rectangle {
      id: dot
      required property int index
      width: 6
      height: 6
      radius: 3
      color: Qt.rgba(0.78, 0.8, 0.8, 0.6)

      SequentialAnimation on opacity {
        running: root.visible
        loops: Animation.Infinite

        PauseAnimation { duration: dot.index * 180 }
        NumberAnimation { to: 1; duration: 300; easing.type: Easing.OutQuad }
        NumberAnimation { to: 0.25; duration: 300; easing.type: Easing.InQuad }
        PauseAnimation { duration: (2 - dot.index) * 180 }
      }

      SequentialAnimation on scale {
        running: root.visible
        loops: Animation.Infinite

        PauseAnimation { duration: dot.index * 180 }
        NumberAnimation { to: 1.35; duration: 300; easing.type: Easing.OutQuad }
        NumberAnimation { to: 0.85; duration: 300; easing.type: Easing.InQuad }
        PauseAnimation { duration: (2 - dot.index) * 180 }
      }
    }
  }
}
