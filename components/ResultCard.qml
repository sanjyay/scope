// ResultCard — displays the agent analysis response.
//
// Shows:
//   Capturing/AgentRunning: loading spinner + "Analyzing…"
//   Complete:               response text + action buttons

import QtQuick
import QtQuick.Effects
import qs.Commons

Rectangle {
  id: root

  property string scopeState: "Idle"
  property string responseText: ""
  property string agentName: ""

  signal closed()
  signal openAgent()

  // ── sizing ────────────────────────────────────────────────────────────────
  implicitHeight: mainColumn.implicitHeight + 28
  radius: 16
  color: Qt.rgba(0.07, 0.08, 0.10, 0.97)
  border.color: Qt.rgba(1, 1, 1, 0.12)
  border.width: 1
  clip: true

  // Drop shadow
  layer.enabled: true
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, 0.65)
    shadowBlur: 0.8
    shadowVerticalOffset: 8
    shadowHorizontalOffset: 0
  }

  // Entrance animation
  opacity: 0
  Component.onCompleted: fadeIn.start()
  NumberAnimation {
    id: fadeIn
    target: root
    property: "opacity"
    to: 1
    duration: 200
    easing.type: Easing.OutQuad
  }

  // ── max height with scroll ────────────────────────────────────────────────

  readonly property int maxHeight: 320

  Column {
    id: mainColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 14
    spacing: 10

    // Loading state
    Row {
      visible: root.scopeState === "Capturing" || root.scopeState === "AgentRunning"
      spacing: 10
      anchors.horizontalCenter: parent.horizontalCenter

      LoadingDots {}

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.scopeState === "Capturing" ? "Capturing…" : "Analyzing…"
        color: Qt.rgba(0.78, 0.8, 0.8, 0.7)
        font.pixelSize: 13
        font.family: Style.font ? Style.font.family : "monospace"
      }
    }

    // Response text (scrollable)
    Item {
      visible: root.scopeState === "Complete"
      width: parent.width
      height: Math.min(root.maxHeight - 80, responseFlick.contentHeight)

      Flickable {
        id: responseFlick
        anchors.fill: parent
        clip: true
        contentWidth: parent.width
        contentHeight: responseText.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Text {
          id: responseText
          width: parent.width
          text: root.responseText
          color: "#d8dbdb"
          font.pixelSize: 13
          font.family: Style.font ? Style.font.family : "monospace"
          wrapMode: Text.Wrap
          lineHeight: 1.5
          textFormat: Text.PlainText
        }
      }

      // Scroll indicator
      Rectangle {
        visible: responseFlick.contentHeight > responseFlick.height
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: -2
        width: 3
        radius: 1.5
        color: Qt.rgba(1, 1, 1, 0.1)

        Rectangle {
          width: parent.width
          height: parent.height * (responseFlick.height / Math.max(1, responseFlick.contentHeight))
          y: responseFlick.visibleArea.yPosition * parent.height
          radius: parent.radius
          color: Qt.rgba(1, 1, 1, 0.35)
        }
      }
    }

    // Action buttons
    Row {
      visible: root.scopeState === "Complete"
      width: parent.width
      spacing: 8

      // Close button
      Rectangle {
        id: closeBtn
        property bool hovered: false
        height: 32
        width: closeLabel.implicitWidth + 24
        radius: 8
        color: closeBtn.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(1, 1, 1, closeBtn.hovered ? 0.20 : 0.10)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
          id: closeLabel
          anchors.centerIn: parent
          text: "Close"
          color: Qt.rgba(0.78, 0.8, 0.8, 0.8)
          font.pixelSize: 12
          font.family: Style.font ? Style.font.family : "monospace"
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: closeBtn.hovered = true
          onExited: closeBtn.hovered = false
          onClicked: root.closed()
        }
      }

      // Open Agent button (explicit escalation boundary)
      Rectangle {
        id: openAgentBtn
        property bool hovered: false
        height: 32
        width: openAgentLabel.implicitWidth + 24
        radius: 8
        color: openAgentBtn.hovered ? Qt.rgba(0.3, 0.6, 0.4, 0.25) : Qt.rgba(0.3, 0.6, 0.4, 0.12)
        border.color: Qt.rgba(0.3, 0.7, 0.5, openAgentBtn.hovered ? 0.45 : 0.25)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
          id: openAgentLabel
          anchors.centerIn: parent
          text: "Open Agent"
          color: Qt.rgba(0.5, 0.9, 0.65, openAgentBtn.hovered ? 1.0 : 0.8)
          font.pixelSize: 12
          font.family: Style.font ? Style.font.family : "monospace"
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: openAgentBtn.hovered = true
          onExited: openAgentBtn.hovered = false
          onClicked: root.openAgent()
        }
      }
    }
  }

  // ── keyboard ──────────────────────────────────────────────────────────────

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return) {
      event.accepted = true
      root.closed()
    }
  }
}
