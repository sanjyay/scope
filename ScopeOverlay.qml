// ScopeOverlay — full-screen Wayland layer surface for a single screen.
//
// One instance per connected screen. Visible only when Scope is active.
// Hosts the lasso canvas, search result card, and error toast.
//
// The overlay is always "mapped" (keepLoaded:true) but only visible and
// interactive when scopeState !== "Idle". Keyboard focus is grabbed only
// while Scope is active so Escape always cancels immediately.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
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
  property var webSources: []
  property string pendingQuestion: ""
  property bool escalationPending: false

  // ── signals to parent ─────────────────────────────────────────────────────
  signal lassoComplete(var points, var bbox)
  signal cancelled()
  signal requestOpenAgent()
  signal followUpSubmitted(string question)
  signal sourceOpenFailed()
  signal dismissed()

  // ── which screen this overlay belongs to ─────────────────────────────────
  // Only show interactive components on the screen where the selection happened.
  // Other screens' overlays only show the dim background.
  readonly property bool isActiveScreen:
    selectionScreen === null || selectionScreen === panel.screen

  // ── Wayland layer shell setup ─────────────────────────────────────────────

  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"

  WlrLayershell.namespace: "omarchy-scope"
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore

  // Grab keyboard to ensure Escape always works
  WlrLayershell.keyboardFocus: (isActiveScreen && scopeState !== "Idle")
    ? WlrKeyboardFocus.Exclusive
    : WlrKeyboardFocus.None

  // Panel is visible whenever Scope is active
  visible: scopeState !== "Idle"

  // ── dim background ────────────────────────────────────────────────────────

  Rectangle {
    anchors.fill: parent
    // Omarchy's image-picker scrim is the shared full-screen overlay role.
    color: Color.imagePicker.scrim
    opacity: {
      switch (scopeState) {
        case "Selecting":    return 0.60
        case "Capturing":
        case "Searching":
        case "Result":       return 1.0
        case "UnsupportedAgent": return 1.0
        case "Error":        return 1.0
        default:             return 0.0
      }
    }
    Behavior on opacity {
      NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
    }
  }


  // ── lasso overlay ─────────────────────────────────────────────────────────

  LassoOverlay {
    id: lasso
    anchors.fill: parent
    visible: isActiveScreen && scopeState === "Selecting"
    enabled: isActiveScreen && scopeState === "Selecting"

    // Screen origin for coordinate conversion (Wayland global space).
    // Required because grim uses global geometry across all monitors.
    screenX: panel.screen.x
    screenY: panel.screen.y

    onComplete: function(points, bbox) {
      panel.lassoComplete(points, bbox)
    }
    onCancelled: panel.cancelled()
  }

  // ── result card ───────────────────────────────────────────────────────────

  ResultCard {
    onOpenAgent: panel.requestOpenAgent()
    onFollowUpSubmitted: function(question) { panel.followUpSubmitted(question) }
    onSourceOpenFailed: panel.sourceOpenFailed()
    id: resultCard
    webSources: panel.webSources

    visible: isActiveScreen && (
      scopeState === "Capturing" || scopeState === "Searching" || scopeState === "Result"
    )
    enabled: isActiveScreen

    scopeState: panel.scopeState
    responseText: panel.responseText
    agentName: panel.detectedAgent
    escalationPending: panel.escalationPending

    // Width and positioning
    readonly property real cw: Math.min(500, panel.width - 48)
    width: cw

    readonly property real localSelX: selectionX - panel.screen.x
    readonly property real localSelY: selectionY - panel.screen.y

    readonly property real anchorCX: selectionW > 0
      ? localSelX + selectionW / 2
      : panel.width / 2
    readonly property real anchorCY: selectionH > 0
      ? localSelY + selectionH + 20
      : panel.height / 2

    x: Math.max(24, Math.min(anchorCX - cw / 2, panel.width - cw - 24))
    y: {
      var yBelow = anchorCY
      return Math.max(24, Math.min(yBelow, panel.height - height - 24))
    }

    onClosed: panel.dismissed()
  }

  // ── unsupported agent notice ──────────────────────────────────────────────

  BorderSurface {
    id: noAgentNotice
    visible: isActiveScreen && scopeState === "UnsupportedAgent"

    anchors.centerIn: parent
    width: Math.min(380, panel.width - 48)
    height: noAgentCol.implicitHeight + Style.spacing.panelPadding * 2
    radius: Style.cornerRadius
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border,
                                  Math.max(1, Style.spacing.hairline))

    Column {
      id: noAgentCol
      anchors.centerIn: parent
      width: parent.width - Style.spacing.panelPadding * 2
      spacing: Style.spacing.xxl

      Text {
    textFormat: Text.PlainText
        width: parent.width
        text: "Scope Search"
        color: Color.popups.text
        font.pixelSize: Style.font.title
        font.family: Style.font.menuFamily
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
      }

      Text {
    textFormat: Text.PlainText
        width: parent.width
        text: "Scope currently supports Codex only.\n\nCurrent Omarchy agent:\n" + panel.displayAgent(panel.detectedAgent) + "\n\nSwitch your default agent to Codex\nand open Scope again."
        color: Color.popups.text
        opacity: 0.78
        font.pixelSize: Style.font.body
        font.family: Style.font.menuFamily
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        lineHeight: 1.4
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        property bool hovered: false
        property bool pressed: false
        width: Style.space(120)
        height: Style.spacing.controlHeight
        radius: Style.cornerRadius
        color: pressed ? Style.pressedFill : Style.controlFill(false, hovered, Color.popups.text, Color.accent)
        border.color: Style.controlBorder(false, hovered, Color.popups.text, Color.accent)
        border.width: Style.controlBorderWidth(false, hovered)

        Text {
    textFormat: Text.PlainText
          anchors.centerIn: parent
          text: "Close"
          color: Color.popups.text
          font.pixelSize: Style.font.body
          font.family: Style.font.menuFamily
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onPressed: parent.pressed = true
          onReleased: parent.pressed = false
          onClicked: panel.cancelled()
        }
      }
    }
  }

  function displayAgent(agent) {
    switch ((agent || "").toLowerCase()) {
      case "codex": return "Codex"
      case "opencode": return "OpenCode"
      case "claude": return "Claude"
      case "antigravity":
      case "agy": return "Antigravity"
      case "grok":
      case "grok-build": return "Grok"
      case "gemini": return "Gemini"
      case "copilot": return "Copilot"
      case "crush": return "Crush"
      case "pi": return "Pi"
      case "omp": return "Oh My Pi"
      default: return "Unknown"
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

  Shortcut {
    sequence: "Escape"
    onActivated: panel.cancelled()
  }

  // ── click-outside dismissal ───────────────────────────────────────────────

  MouseArea {
    anchors.fill: parent
    z: -1
    enabled: isActiveScreen && scopeState === "Result"
    onClicked: panel.cancelled()
  }
}
