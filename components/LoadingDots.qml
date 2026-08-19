// LoadingDots — animated three-dot loading indicator.
// Minimal, non-blocking. Dots pulse with staggered delays.

import QtQuick
import qs.Commons

Row {
  id: root
  spacing: Style.spacing.sm

  Repeater {
    model: 3

    Rectangle {
      id: dot
      required property int index
      width: Style.spacing.md
      height: Style.spacing.md
      radius: Math.min(Style.cornerRadius, width / 2)
      color: Color.accent

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
