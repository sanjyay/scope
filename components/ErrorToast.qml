// ErrorToast — brief ephemeral error message overlay.
// Auto-hides after the parent sets its errorText to "".

import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string message: ""

  implicitWidth: toastRow.implicitWidth + Style.spacing.panelPadding * 2
  implicitHeight: Math.max(Style.spacing.controlHeight + Style.spacing.sm,
                           toastRow.implicitHeight + Style.spacing.controlPaddingY * 2)
  radius: Style.cornerRadius
  color: Color.notifications.background
  borderSpec: Border.surfaceSpec("notifications", "border", Color.notifications.border,
                                Math.max(1, Style.spacing.hairline))

  layer.enabled: true
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Color.background
    shadowOpacity: 0.5
    shadowBlur: 0.7
    shadowVerticalOffset: 4
  }

  Row {
    id: toastRow
    anchors.centerIn: parent
    spacing: Style.spacing.controlGap

    Text {
      text: "⚠"
      color: Color.urgent
      font.pixelSize: Style.font.body
      font.family: Style.font.menuFamily
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: root.message
      color: Color.notifications.text
      font.pixelSize: Style.font.body
      font.family: Style.font.menuFamily
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }
}
