// ScopeOverlay — full-screen Wayland layer surface for a single screen.
//
// One instance per connected screen. Visible only when Scope is active.
// Hosts the lasso canvas, ask bubble, result card, and error toast.
//
// The overlay is always "mapped" (keepLoaded:true) but only visible and
// interactive when scopeState !== "Idle". Keyboard focus is grabbed only
// when the text input is needed (Prompting or Complete states).

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "components"

PanelWindow {
  id: panel

  // ── inputs from parent (Scope.qml) ───────────────────────────────────────
  required property var screen
  property string scopeState: "Idle"
  property var lassoPoints: []
  property int selectionX: 0
  property int selectionY: 0
  property int selectionW: 0
  property int selectionH: 0
  property var selectionScreen: null
  property string detectedAgent: ""
  property bool agentDetected: false
  property bool agentDetectionDone: false
  property string responseText: ""
  property string errorText: ""

  // ── signals to parent ─────────────────────────────────────────────────────
  signal lassoComplete(var points, var bbox)
  signal questionSubmitted(string question)
  signal cancelled()
  signal dismissed()

  // ── which screen this overlay belongs to ─────────────────────────────────
  // Only show interactive components on the screen where the selection happened.
  // Other screens' overlays only show the dim background.
  readonly property bool isActiveScreen:
    selectionScreen === null || selectionScreen === panel.screen

  // ── Wayland layer shell setup ─────────────────────────────────────────────

  QsWindow.screen: panel.screen
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"

  WlrLayershell.namespace: "omarchy-scope"
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore

  // Grab keyboard only when input is needed
  WlrLayershell.keyboardFocus: (
    isActiveScreen &&
    (scopeState === "Prompting" || scopeState === "Complete")
  ) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  // Panel is visible whenever Scope is active
  visible: scopeState !== "Idle"

  // ── dim background ────────────────────────────────────────────────────────

  Rectangle {
    anchors.fill: parent
    color: "black"
    opacity: {
      switch (scopeState) {
        case "Selecting":    return 0.30
        case "Prompting":
        case "Capturing":
        case "AgentRunning":
        case "Complete":     return 0.52
        default:             return 0.0
      }
    }
    Behavior on opacity {
      NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
    }
  }

  // ── selected region highlight ─────────────────────────────────────────────
  // After the lasso is released, keep the selection area brighter.
  // We draw a hole in the dim by placing a transparent rect with a subtle border.

  Rectangle {
    id: selHighlight
    visible: isActiveScreen && selectionW > 0 && selectionH > 0 && (
      scopeState === "Prompting" ||
      scopeState === "Capturing" ||
      scopeState === "AgentRunning" ||
      scopeState === "Complete"
    )

    // selectionX/Y are screen-absolute; this PanelWindow covers the whole screen
    // anchored to the screen origin, so we use the coords directly.
    x: selectionX
    y: selectionY
    width: selectionW
    height: selectionH
    color: "transparent"
    radius: 4

    // Bright border around the selection
    Rectangle {
      anchors.fill: parent
      anchors.margins: -2
      color: "transparent"
      border.color: Qt.rgba(1, 1, 1, 0.35)
      border.width: 1.5
      radius: parent.radius + 2
    }

    // Corner accent dots
    Repeater {
      model: [
        { ax: 0, ay: 0, ax2: 0, ay2: 0 },          // top-left
        { ax: 1, ay: 0, ax2: -6, ay2: 0 },          // top-right
        { ax: 0, ay: 1, ax2: 0, ay2: -6 },          // bottom-left
        { ax: 1, ay: 1, ax2: -6, ay2: -6 }          // bottom-right
      ]

      Rectangle {
        required property var modelData
        x: selHighlight.width * modelData.ax + modelData.ax2
        y: selHighlight.height * modelData.ay + modelData.ay2
        width: 6
        height: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.7)
      }
    }
  }

  // ── lasso overlay ─────────────────────────────────────────────────────────

  LassoOverlay {
    id: lasso
    anchors.fill: parent
    visible: isActiveScreen && scopeState === "Selecting"
    enabled: isActiveScreen && scopeState === "Selecting"

    // Screen origin for coordinate conversion.
    // In a full-screen PanelWindow, the window origin IS the screen origin.
    screenX: 0
    screenY: 0

    onComplete: function(points, bbox) {
      panel.lassoComplete(points, bbox)
    }
    onCancelled: panel.cancelled()
  }

  // ── ask bubble ────────────────────────────────────────────────────────────

  AskBubble {
    id: askBubble

    visible: isActiveScreen && scopeState === "Prompting"
    enabled: isActiveScreen && scopeState === "Prompting"

    // Width and positioning
    readonly property real bw: Math.min(380, panel.width - 48)
    width: bw

    // Anchor point: center-bottom of the selection (or center of screen)
    readonly property real anchorCX: selectionW > 0
      ? selectionX + selectionW / 2
      : panel.width / 2
    readonly property real anchorCY: selectionH > 0
      ? selectionY + selectionH
      : panel.height / 2

    x: Math.max(16, Math.min(anchorCX - bw / 2, panel.width - bw - 16))
    y: {
      var below = anchorCY + 16
      var above = (selectionH > 0 ? selectionY : panel.height / 2) - implicitHeight - 16
      return (below + implicitHeight < panel.height - 16) ? below : Math.max(16, above)
    }

    agentName: panel.detectedAgent
    agentDetected: panel.agentDetected
    agentDetectionDone: panel.agentDetectionDone

    onSubmitted: function(question) { panel.questionSubmitted(question) }
    onCancelled: panel.cancelled()

    onVisibleChanged: {
      if (visible) Qt.callLater(function() { askBubble.focusInput() })
    }
  }

  // ── result card ───────────────────────────────────────────────────────────

  ResultCard {
    id: resultCard

    visible: isActiveScreen && (
      scopeState === "Capturing" ||
      scopeState === "AgentRunning" ||
      scopeState === "Complete"
    )
    enabled: isActiveScreen

    scopeState: panel.scopeState
    responseText: panel.responseText
    agentName: panel.detectedAgent

    // Width and positioning
    readonly property real cw: Math.min(500, panel.width - 48)
    width: cw

    readonly property real anchorCX: selectionW > 0
      ? selectionX + selectionW / 2
      : panel.width / 2
    readonly property real anchorCY: selectionH > 0
      ? selectionY + selectionH + 20
      : panel.height / 2

    x: Math.max(24, Math.min(anchorCX - cw / 2, panel.width - cw - 24))
    y: {
      var yBelow = anchorCY
      return Math.max(24, Math.min(yBelow, panel.height - height - 24))
    }

    onClosed: panel.dismissed()
  }

  // ── unsupported agent notice ──────────────────────────────────────────────

  Rectangle {
    id: noAgentNotice
    visible: isActiveScreen && scopeState === "Prompting" &&
             panel.agentDetectionDone && !panel.agentDetected

    anchors.centerIn: parent
    width: Math.min(380, panel.width - 48)
    height: noAgentCol.implicitHeight + 40
    radius: 14
    color: Qt.rgba(0.07, 0.08, 0.10, 0.97)
    border.color: Qt.rgba(1, 0.35, 0.35, 0.5)
    border.width: 1

    Column {
      id: noAgentCol
      anchors.centerIn: parent
      width: parent.width - 40
      spacing: 12

      Text {
        width: parent.width
        text: "No supported AI agent found"
        color: "#cacccc"
        font.pixelSize: 15
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
      }

      Text {
        width: parent.width
        text: "Scope requires Codex or Claude Code to be installed.\n\nInstall one to use Scope."
        color: Qt.rgba(0.78, 0.8, 0.8, 0.75)
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        lineHeight: 1.4
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 120
        height: 34
        radius: 8
        color: Qt.rgba(0.78, 0.8, 0.8, 0.10)
        border.color: Qt.rgba(0.78, 0.8, 0.8, 0.20)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "Cancel"
          color: "#cacccc"
          font.pixelSize: 13
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: panel.cancelled()
        }
      }
    }
  }

  // ── error toast ───────────────────────────────────────────────────────────

  ErrorToast {
    visible: isActiveScreen && panel.errorText !== ""
    message: panel.errorText
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: 40
  }

  // ── global key handler ────────────────────────────────────────────────────

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      event.accepted = true
      panel.cancelled()
    }
  }

  // ── click-outside dismissal ───────────────────────────────────────────────

  MouseArea {
    anchors.fill: parent
    z: -1
    enabled: isActiveScreen && (scopeState === "Prompting" || scopeState === "Complete")
    onClicked: panel.cancelled()
  }
}
