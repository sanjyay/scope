import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string readinessStatus: ""
  property bool retryInProgress: false
  readonly property string setupCommand:
    "codex -c 'cli_auth_credentials_store=\"keyring\"' login --device-auth"
  readonly property bool setupShowCommand: readinessStatus === "keyring_login_required"
  readonly property bool setupCanCopy: setupShowCommand
  readonly property string setupTitle: {
    switch (readinessStatus) {
      case "": return "Checking protected Search…"
      case "codex_missing": return "Codex CLI required"
      case "bwrap_missing": return "Protected Search unavailable"
      case "secret_service_unavailable": return "OS keyring unavailable"
      case "keyring_login_required": return "Codex setup required"
      default: return "Protected Search unavailable"
    }
  }
  readonly property string setupMessage: {
    switch (readinessStatus) {
      case "": return "Checking local prerequisites."
      case "codex_missing": return "Scope's protected Search requires the Codex CLI. Install and configure Codex using the normal Omarchy/Codex workflow, then open Scope again."
      case "bwrap_missing": return "Scope requires bubblewrap to isolate Codex from local files."
      case "secret_service_unavailable": return "Scope could not access the Secret Service required for protected Codex authentication."
      case "keyring_login_required": return "Scope's protected Search requires Codex to use your OS keyring for ChatGPT authentication."
      default: return "Scope could not establish its protected Codex environment."
    }
  }

  signal copyRequested(string command)
  signal retryRequested()
  signal closeRequested()

  width: Math.min(520, parent ? parent.width - 48 : 520)
  height: content.implicitHeight + Style.spacing.panelPadding * 2
  radius: Style.cornerRadius
  color: Color.popups.background
  borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border,
                                Math.max(1, Style.spacing.hairline))

  ColumnLayout {
    id: content
    anchors.centerIn: parent
    width: parent.width - Style.spacing.panelPadding * 2
    spacing: Style.spacing.xxl

    Image {
      Layout.alignment: Qt.AlignHCenter
      source: Qt.resolvedUrl("../assets/scope.svg")
      sourceSize.width: Style.font.display
      sourceSize.height: Style.font.display
      width: Style.font.display
      height: Style.font.display
    }

    Text {
      Layout.fillWidth: true
      text: root.setupTitle
      textFormat: Text.PlainText
      color: Color.popups.text
      font.pixelSize: Style.font.title
      font.family: Style.font.menuFamily
      font.weight: Font.Medium
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
    }

    Text {
      Layout.fillWidth: true
      text: root.setupMessage
      textFormat: Text.PlainText
      color: Color.popups.text
      opacity: 0.78
      font.pixelSize: Style.font.body
      font.family: Style.font.menuFamily
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      lineHeight: 1.35
    }

    Text {
      visible: root.setupShowCommand
      Layout.fillWidth: true
      text: "Run:"
      textFormat: Text.PlainText
      color: Color.popups.text
      opacity: 0.78
      font.pixelSize: Style.font.body
      font.family: Style.font.menuFamily
    }

    Rectangle {
      visible: root.setupShowCommand
      Layout.fillWidth: true
      implicitHeight: commandText.implicitHeight + Style.spacing.lg * 2
      radius: Style.cornerRadius
      color: Style.controlFill(false, false, Color.popups.text, Color.accent)

      Text {
        id: commandText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Style.spacing.lg
        anchors.rightMargin: Style.spacing.lg
        anchors.verticalCenter: parent.verticalCenter
        text: root.setupCommand
        textFormat: Text.PlainText
        visible: root.setupCommand.length > 0
        color: Color.popups.text
        font.pixelSize: Style.font.caption
        font.family: Style.fontFamily
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
      }
    }

    Text {
      visible: root.setupShowCommand
      Layout.fillWidth: true
      text: "Then return here and retry.\n\nThis uses your ChatGPT login. Scope does not store your credentials."
      textFormat: Text.PlainText
      color: Color.popups.text
      opacity: 0.78
      font.pixelSize: Style.font.body
      font.family: Style.font.menuFamily
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.lg

      Rectangle {
        visible: root.setupCanCopy
        property bool hovered: false
        property bool pressed: false
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: Style.spacing.controlHeight
        radius: Style.cornerRadius
        color: pressed ? Style.pressedFill : Style.controlFill(false, hovered, Color.popups.text, Color.accent)
        border.color: Style.controlBorder(false, hovered, Color.popups.text, Color.accent)
        border.width: Style.controlBorderWidth(false, hovered)

        Text {
          anchors.centerIn: parent
          text: "Copy command"
          textFormat: Text.PlainText
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
          onClicked: root.copyRequested(root.setupCommand)
        }
      }

      Rectangle {
        property bool hovered: false
        property bool pressed: false
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: Style.spacing.controlHeight
        radius: Style.cornerRadius
        opacity: root.retryInProgress ? 0.5 : 1.0
        color: pressed ? Style.pressedFill : Style.controlFill(false, hovered, Color.popups.text, Color.accent)
        border.color: Style.controlBorder(false, hovered, Color.popups.text, Color.accent)
        border.width: Style.controlBorderWidth(false, hovered)

        Text {
          anchors.centerIn: parent
          text: "Retry"
          textFormat: Text.PlainText
          color: Color.popups.text
          font.pixelSize: Style.font.body
          font.family: Style.font.menuFamily
        }
        MouseArea {
          anchors.fill: parent
          enabled: !root.retryInProgress
          hoverEnabled: enabled
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onPressed: parent.pressed = true
          onReleased: parent.pressed = false
          onClicked: root.retryRequested()
        }
      }

      Rectangle {
        property bool hovered: false
        property bool pressed: false
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: Style.spacing.controlHeight
        radius: Style.cornerRadius
        color: pressed ? Style.pressedFill : Style.controlFill(false, hovered, Color.popups.text, Color.accent)
        border.color: Style.controlBorder(false, hovered, Color.popups.text, Color.accent)
        border.width: Style.controlBorderWidth(false, hovered)

        Text {
          anchors.centerIn: parent
          text: "Close"
          textFormat: Text.PlainText
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
          onClicked: root.closeRequested()
        }
      }
    }
  }
}
