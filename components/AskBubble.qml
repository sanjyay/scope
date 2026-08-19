// AskBubble — compact prompt input near the lasso selection.
//
// Shows a text input with placeholder "Ask about this…" and quick-action
// chips. Submit on Enter; Shift+Enter for newline; Esc to cancel.

import QtQuick
import QtQuick.Effects

Rectangle {
  id: root

  property string agentName: ""
  property bool agentDetected: true
  property bool agentDetectionDone: true

  signal submitted(string question)
  signal cancelled()

  function focusInput() {
    questionInput.forceActiveFocus()
  }

  // ── sizing and appearance ─────────────────────────────────────────────────
  implicitHeight: mainCol.implicitHeight + 28
  radius: 16
  color: Qt.rgba(0.07, 0.08, 0.10, 0.97)
  border.color: Qt.rgba(1, 1, 1, 0.12)
  border.width: 1
  clip: false

  layer.enabled: true
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, 0.65)
    shadowBlur: 0.8
    shadowVerticalOffset: 8
  }

  // Entrance animation
  opacity: 0
  scale: 0.94
  Component.onCompleted: {
    opAnim.start()
    scaleAnim.start()
  }

  NumberAnimation {
    id: opAnim
    target: root; property: "opacity"
    to: 1; duration: 155; easing.type: Easing.OutQuad
  }
  NumberAnimation {
    id: scaleAnim
    target: root; property: "scale"
    to: 1; duration: 175; easing.type: Easing.OutBack; easing.overshoot: 1.0
  }

  // ── layout ────────────────────────────────────────────────────────────────

  Column {
    id: mainCol
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 12
    spacing: 8

    // ── text input ───────────────────────────────────────────────────────
    Rectangle {
      id: inputBg
      width: parent.width
      height: Math.max(40, questionInput.contentHeight + 20)
      radius: 10
      color: Qt.rgba(1, 1, 1, 0.06)
      border.color: questionInput.activeFocus
        ? Qt.rgba(1, 1, 1, 0.30)
        : Qt.rgba(1, 1, 1, 0.10)
      border.width: 1

      Behavior on border.color { ColorAnimation { duration: 100 } }

      // Placeholder
      Text {
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
          margins: 12
          topMargin: 11
        }
        text: "Ask about this…"
        color: Qt.rgba(0.78, 0.8, 0.8, 0.40)
        font.pixelSize: 14
        visible: !questionInput.text
      }

      TextEdit {
        id: questionInput
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
          margins: 12
          topMargin: 11
        }
        color: "#dcdfe0"
        font.pixelSize: 14
        wrapMode: TextEdit.Wrap
        selectByMouse: true
        activeFocusOnTab: true

        Keys.onPressed: function(event) {
          if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
              !(event.modifiers & Qt.ShiftModifier)) {
            event.accepted = true
            root.doSubmit()
          } else if (event.key === Qt.Key_Escape) {
            event.accepted = true
            root.cancelled()
          }
        }
      }
    }

    // ── quick chips row ──────────────────────────────────────────────────
    Row {
      width: parent.width
      spacing: 6

      Repeater {
        model: ["Explain", "What is this?"]

        delegate: Rectangle {
          id: chip
          property bool chipHovered: false
          height: 28
          width: chipText.implicitWidth + 20
          radius: 14
          color: chip.chipHovered ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.07)
          border.color: Qt.rgba(1, 1, 1, chip.chipHovered ? 0.22 : 0.10)
          border.width: 1

          Behavior on color { ColorAnimation { duration: 80 } }

          Text {
            id: chipText
            anchors.centerIn: parent
            text: modelData
            color: Qt.rgba(0.78, 0.8, 0.8, 0.85)
            font.pixelSize: 12
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: chip.chipHovered = true
            onExited: chip.chipHovered = false
            onClicked: {
              questionInput.text = modelData
              root.doSubmit()
            }
          }
        }
      }

      // Push agent badge to the right
      Item {
        width: parent.width - (parent.contentWidth || 0)
        height: 28
        // spacer — computed at runtime
      }

      // Agent badge
      Rectangle {
        visible: root.agentDetectionDone && root.agentDetected
        height: 28
        width: badgeText.implicitWidth + 16
        radius: 14
        color: Qt.rgba(0.25, 0.55, 0.38, 0.15)
        border.color: Qt.rgba(0.3, 0.7, 0.5, 0.30)
        border.width: 1

        Text {
          id: badgeText
          anchors.centerIn: parent
          text: root.agentName === "codex" ? "Codex" :
                root.agentName === "claude" ? "Claude" : ""
          color: Qt.rgba(0.45, 0.85, 0.60, 0.90)
          font.pixelSize: 11
        }
      }
    }

    // ── hint text ────────────────────────────────────────────────────────
    Text {
      width: parent.width
      text: "Enter to ask  ·  Esc to cancel"
      color: Qt.rgba(0.78, 0.8, 0.8, 0.28)
      font.pixelSize: 11
      horizontalAlignment: Text.AlignRight
    }
  }

  // ── submit ────────────────────────────────────────────────────────────────

  function doSubmit() {
    var q = questionInput.text.trim()
    if (!q) return
    root.submitted(q)
  }
}
