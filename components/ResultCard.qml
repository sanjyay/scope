// ResultCard — displays a protected Scope Search result.
//
// Shows:
//   Capturing/Searching: loading spinner + "Searching…"
//   Result:              response text, sources, follow-up, and escalation

import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string scopeState: "Idle"
  property string responseText: ""
  property string agentName: ""
  property var webSources: []
  property string activityTitle: ""
  property string activityDetail: ""
  property bool isExpanded: false
  property bool escalationPending: false

  onScopeStateChanged: {
    if (scopeState === "Result") {
      Qt.callLater(focusFollowUp)
    }
  }

  function safeWebUrl(value) {
    if (typeof value !== "string") return ""
    var url = value.trim()
    if (!url || url.length > 4096 || /[\s<>"'`\\]/.test(url)) return ""
    var match = url.match(/^https?:\/\/([A-Za-z0-9.-]+(?::[0-9]{1,5})?)(?:[/?#][^\s]*)?$/i)
    if (!match) return ""
    var host = match[1].replace(/:\d+$/, "")
    if (!host || host.charAt(0) === "." || host.charAt(host.length - 1) === ".") return ""
    return url
  }

  function sourceTitle(source, index) {
    if (source && typeof source.title === "string" && source.title.trim())
      return source.title.trim()
    return "Source " + String(index + 1)
  }

  function formatModelAnswerAsPlain(value) {
    var source = String(value || "")
    var pattern = /\[([^\]\r\n]{1,512})\]\(([^)\r\n]{1,4096})\)/g
    var result = ""
    var cursor = 0
    var match
    while ((match = pattern.exec(source)) !== null) {
      result += source.slice(cursor, match.index)
      var label = match[1]
      result += label
      cursor = pattern.lastIndex
    }
    return result + source.slice(cursor)
  }

  function openWebUrl(value) {
    var url = safeWebUrl(value)
    if (!url) {
      root.sourceOpenFailed()
      return false
    }
    if (browserOpenProc.running) return true
    browserOpenProc.command = ["xdg-open", url]
    browserOpenProc.running = true
    return true
  }

  function focusFollowUp() {
    followUp.forceActiveFocus()
  }

  signal closed()
  signal openAgent()
  signal followUpSubmitted(string question)
  signal sourceOpenFailed()

  Process {
    id: browserOpenProc
    running: false
    command: []
    onExited: function(code) {
      if (code !== 0) root.sourceOpenFailed()
    }
  }

  // ── sizing ────────────────────────────────────────────────────────────────
  implicitHeight: mainColumn.implicitHeight + Style.spacing.popupPadding * 2
  radius: Style.cornerRadius
  color: Color.popups.background
  borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border,
                                Math.max(1, Style.spacing.hairline))
  clip: true

  // Drop shadow
  layer.enabled: true
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Color.background
    shadowOpacity: 0.55
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

  readonly property int maxHeight: isExpanded ? Style.space(520) : Style.space(320)

  Column {
    id: mainColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.spacing.popupPadding
    spacing: Style.spacing.lg

    // Loading state
    Row {
      visible: root.scopeState === "Capturing" || root.scopeState === "Searching"
      spacing: Style.spacing.lg
      anchors.horizontalCenter: parent.horizontalCenter

      LoadingDots {}

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.xs

        Text {
          textFormat: Text.PlainText
          text: root.activityTitle !== "" ? root.activityTitle : "Analyzing selection…"
          color: Color.popups.text
          opacity: 0.72
          font.pixelSize: Style.font.body
          font.family: Style.font.menuFamily
        }

        Text {
          textFormat: Text.PlainText
          visible: root.activityDetail !== ""
          text: root.activityDetail
          color: Color.popups.text
          opacity: 0.50
          font.pixelSize: Style.font.small
          font.family: Style.font.menuFamily
          elide: Text.ElideRight
          width: Math.min(implicitWidth, 250)
        }
      }
    }

    // Response text (scrollable)
    Item {
      visible: root.scopeState === "Result"
      width: parent.width
      height: Math.min(root.maxHeight - 80, responseFlick.contentHeight)

      Flickable {
        id: responseFlick
        anchors.fill: parent
        clip: true
        contentWidth: parent.width
        contentHeight: contentCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: contentCol
          width: parent.width
          spacing: Style.spacing.xxl

          Text {
    textFormat: Text.PlainText
            id: responseText
            width: parent.width
            text: root.formatModelAnswerAsPlain(root.responseText)
            color: Color.popups.text
            font.pixelSize: Style.font.body
            font.family: Style.font.menuFamily
            wrapMode: Text.Wrap
            lineHeight: 1.5
          }

          // Sources Section
          Column {
            visible: root.webSources && root.webSources.length > 0
            width: parent.width
            spacing: Style.spacing.controlGap

            Text {
    textFormat: Text.PlainText
              text: "Sources"
              color: Color.popups.text
              opacity: 0.72
              font.pixelSize: Style.font.bodySmall
              font.family: Style.font.menuFamily
              font.bold: true
            }

            // Collapsed view (Chips)
            Row {
              visible: !root.isExpanded
              spacing: Style.spacing.sm
              Repeater {
                model: root.webSources.slice(0, 3)
                delegate: Rectangle {
                  property bool hovered: false
                  property bool pressed: false
                  // Keep the Row's implicit-width calculation acyclic while still
                  // leaving room for a useful, themed source label.
                  width: Math.min(sourceChipLabel.implicitWidth + Style.spacing.controlPaddingX * 2,
                                  Style.space(190))
                  height: Style.spacing.controlHeight
                  radius: Style.cornerRadius
                  color: pressed ? Style.pressedFill : Style.controlFill(false, hovered, Color.popups.text, Color.accent)
                  border.color: Style.controlBorder(false, hovered, Color.popups.text, Color.accent)
                  border.width: Style.controlBorderWidth(false, hovered)

                  Text {
    textFormat: Text.PlainText
                    id: sourceChipLabel
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.spacing.controlPaddingX
                    anchors.rightMargin: Style.spacing.controlPaddingX
                    text: String(index + 1) + " · " + root.sourceTitle(modelData, index)
                    color: Color.menu.selectedText
                    font.pixelSize: Style.font.bodySmall
                    font.family: Style.font.menuFamily
                    elide: Text.ElideRight
                    maximumLineCount: 1
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false
                    onPressed: parent.pressed = true
                    onReleased: parent.pressed = false
                    onClicked: root.openWebUrl(modelData.url)
                  }
                }
              }
            }

            // Expanded view (List)
            Column {
              visible: root.isExpanded
              width: parent.width
              spacing: Style.spacing.sm

              Repeater {
                model: root.webSources
                delegate: Rectangle {
                  property bool hovered: false
                  property bool pressed: false
                  width: parent.width
                  height: sourceCol.implicitHeight + Style.spacing.xxl
                  radius: Style.cornerRadius
                  color: pressed ? Style.pressedFill : Style.controlFill(false, hovered, Color.popups.text, Color.accent)
                  border.color: Style.controlBorder(false, hovered, Color.popups.text, Color.accent)
                  border.width: Style.controlBorderWidth(false, hovered)

                  Column {
                    id: sourceCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Style.spacing.rowPaddingX
                    spacing: Style.spacing.sm

                    Text {
    textFormat: Text.PlainText
                      width: parent.width
                      text: String(index + 1) + ". " + root.sourceTitle(modelData, index)
                      color: Color.popups.text
                      font.pixelSize: Style.font.bodySmall
                      font.family: Style.font.menuFamily
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    Text {
    textFormat: Text.PlainText
                      width: parent.width
                      text: modelData.url
                      color: Color.accent
                      font.pixelSize: Style.font.caption
                      font.family: Style.font.menuFamily
                      elide: Text.ElideRight
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false
                    onPressed: parent.pressed = true
                    onReleased: parent.pressed = false
                    onClicked: root.openWebUrl(modelData.url)
                  }
                }
              }
            }
          }
        }
      }

      // Scroll indicator
      Rectangle {
        visible: responseFlick.contentHeight > responseFlick.height
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: -2
        width: Math.max(Style.spacing.hairline, Style.space(3))
        radius: Math.min(Style.cornerRadius, width / 2)
        color: Color.muted
        opacity: 0.28

        Rectangle {
          width: parent.width
          height: parent.height * (responseFlick.height / Math.max(1, responseFlick.contentHeight))
          y: responseFlick.visibleArea.yPosition * parent.height
          radius: parent.radius
          color: Color.accent
          opacity: 0.72
        }
      }
    }

    // Follow-up stays in the protected Scope Search path and reuses the private
    // lasso image. It never opens the unrestricted interactive agent.
    Rectangle {
      visible: root.scopeState === "Result"
      width: parent.width
      height: Math.max(Style.spacing.controlHeight + Style.spacing.sm, Style.font.body + Style.spacing.inputPaddingY * 2)
      radius: Style.cornerRadius
      color: Style.controlFill(followUp.activeFocus, false, Color.popups.text, Color.accent)
      border.color: Style.controlBorder(followUp.activeFocus, false, Color.popups.text, Color.accent)
      border.width: Style.controlBorderWidth(followUp.activeFocus, false)

      Text {
    textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.spacing.controlPaddingX
        text: "Ask follow-up…"
        visible: !followUp.text
        color: Color.muted
        font.pixelSize: Style.font.body
        font.family: Style.font.menuFamily
      }

      TextInput {
        id: followUp
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.controlPaddingX
        anchors.rightMargin: Style.spacing.controlPaddingX
        verticalAlignment: TextInput.AlignVCenter
        color: Color.popups.text
        selectionColor: Style.selectionFill
        selectedTextColor: Color.popups.text
        cursorVisible: true
        font.pixelSize: Style.font.body
        font.family: Style.font.menuFamily
        selectByMouse: true
        clip: true
        onAccepted: {
          var question = text.trim()
          if (!question) return
          text = ""
          root.followUpSubmitted(question)
        }
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            event.accepted = true
            root.closed()
          }
        }
      }
    }

    // Action buttons
    Row {
      visible: root.scopeState === "Result"
      width: parent.width
      spacing: Style.spacing.controlGap

      // Expand button
      Rectangle {
        id: expandBtn
        visible: root.webSources && root.webSources.length > 0
        property bool hovered: false
        property bool pressed: false
        height: Style.spacing.controlHeight
        width: expandLabel.implicitWidth + Style.spacing.controlPaddingX * 2
        radius: Style.cornerRadius
        color: pressed ? Style.pressedFill : Style.controlFill(false, hovered, Color.popups.text, Color.accent)
        border.color: Style.controlBorder(false, hovered, Color.popups.text, Color.accent)
        border.width: Style.controlBorderWidth(false, hovered)

        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
    textFormat: Text.PlainText
          id: expandLabel
          anchors.centerIn: parent
          text: root.isExpanded ? "Collapse" : "Expand"
          color: Color.popups.text
          font.pixelSize: Style.font.bodySmall
          font.family: Style.font.menuFamily
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: expandBtn.hovered = true
          onExited: expandBtn.hovered = false
          onPressed: expandBtn.pressed = true
          onReleased: expandBtn.pressed = false
          onClicked: root.isExpanded = !root.isExpanded
        }
      }

      // Close button
      Rectangle {
        id: closeBtn
        property bool hovered: false
        property bool pressed: false
        height: Style.spacing.controlHeight
        width: closeLabel.implicitWidth + Style.spacing.controlPaddingX * 2
        radius: Style.cornerRadius
        color: pressed ? Style.pressedFill : Style.controlFill(false, hovered, Color.popups.text, Color.accent)
        border.color: Style.controlBorder(false, hovered, Color.popups.text, Color.accent)
        border.width: Style.controlBorderWidth(false, hovered)

        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
    textFormat: Text.PlainText
          id: closeLabel
          anchors.centerIn: parent
          text: "Close"
          color: Color.popups.text
          font.pixelSize: Style.font.bodySmall
          font.family: Style.font.menuFamily
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: closeBtn.hovered = true
          onExited: closeBtn.hovered = false
          onPressed: closeBtn.pressed = true
          onReleased: closeBtn.pressed = false
          onClicked: root.closed()
        }
      }

      // Open Agent button (explicit escalation boundary)
      Rectangle {
        id: openAgentBtn
        property bool hovered: false
        property bool pressed: false
        enabled: !root.escalationPending
        opacity: enabled ? 1 : 0.55
        height: Style.spacing.controlHeight
        width: openAgentLabel.implicitWidth + Style.spacing.controlPaddingX * 2
        radius: Style.cornerRadius
        color: pressed ? Style.pressedFill : Style.selectedFill
        border.color: Style.selectedBorderColor
        border.width: Math.max(Style.selectedBorderWidth, Style.spacing.hairline)

        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
    textFormat: Text.PlainText
          id: openAgentLabel
          anchors.centerIn: parent
          text: root.escalationPending ? "Opening…" : "Open Agent"
          color: Color.menu.selectedText
          font.pixelSize: Style.font.bodySmall
          font.family: Style.font.menuFamily
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          enabled: openAgentBtn.enabled
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onEntered: openAgentBtn.hovered = true
          onExited: openAgentBtn.hovered = false
          onPressed: openAgentBtn.pressed = true
          onReleased: openAgentBtn.pressed = false
          onClicked: root.openAgent()
        }
      }
    }
  }

  // ── keyboard ──────────────────────────────────────────────────────────────

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      event.accepted = true
      root.closed()
    }
  }
}
