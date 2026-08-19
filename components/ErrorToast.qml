// ErrorToast — brief ephemeral error message overlay.
// Auto-hides after the parent sets its errorText to "".

import QtQuick
import QtQuick.Effects

Rectangle {
  id: root

  property string message: ""

  implicitWidth: toastRow.implicitWidth + 32
  implicitHeight: 40
  radius: 20
  color: Qt.rgba(0.55, 0.18, 0.18, 0.95)
  border.color: Qt.rgba(1, 0.4, 0.4, 0.4)
  border.width: 1

  layer.enabled: true
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, 0.5)
    shadowBlur: 0.7
    shadowVerticalOffset: 4
  }

  Row {
    id: toastRow
    anchors.centerIn: parent
    spacing: 8

    Text {
      text: "⚠"
      color: Qt.rgba(1, 0.7, 0.7, 0.9)
      font.pixelSize: 13
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: root.message
      color: Qt.rgba(1, 0.78, 0.78, 0.95)
      font.pixelSize: 13
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }
}
