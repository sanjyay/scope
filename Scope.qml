// Scope — circle anything on screen and ask your AI agent about it.
//
// Entry point for the "overlay" kind. keepLoaded: true so the surface is
// available instantly on hotkey without load latency.
//
// State machine:
//   Idle → Selecting → Prompting → Capturing → AgentRunning → Complete
//   Any state → Idle (via cancel/Esc/dismiss)

import QtQuick
import Quickshell
import Quickshell.Io
import "components"

Item {
  id: root

  // ── injected by shell host ────────────────────────────────────────────────
  property var shell: null
  property var manifest: null

  // ── plugin paths ──────────────────────────────────────────────────────────
  // Quickshell.shellDir is the shell's dir, not our plugin dir.
  // We rely on OMARCHY_PATH + our plugin id to locate scripts.
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || ""
  readonly property string pluginId: "goblin.scope"

  // The plugin dir is determined at install time.
  // Scripts are located relative to the manifest, which is our plugin dir.
  // In Quickshell, Qt.resolvedUrl(".") gives the dir of the QML file.
  readonly property string pluginDir: {
    var url = Qt.resolvedUrl(".")
    // Strip file:// prefix
    return url.replace(/^file:\/\//, "").replace(/\/$/, "")
  }
  readonly property string helperScript: pluginDir + "/scripts/scope-helper"
  readonly property string detectScript: pluginDir + "/scripts/scope-detect-agent"

  // ── state machine ─────────────────────────────────────────────────────────
  // "Idle" | "Selecting" | "Prompting" | "Capturing" | "AgentRunning" | "Complete"
  property string scopeState: "Idle"

  // ── selection data ────────────────────────────────────────────────────────
  property var lassoPoints: []       // [{x,y}] screen-absolute
  property var imageLassoPoints: []  // [{x,y}] image-relative (for masking)
  property int selectionX: 0        // bounding box, screen-absolute
  property int selectionY: 0
  property int selectionW: 0
  property int selectionH: 0
  property var selectionScreen: null

  // ── agent ─────────────────────────────────────────────────────────────────
  property string detectedAgent: ""
  property bool agentDetected: false
  property bool agentDetectionDone: false

  // ── invocation ────────────────────────────────────────────────────────────
  property string invocationId: ""
  property string capturedImagePath: ""
  property string responseText: ""
  property string errorText: ""

  // ── guard against concurrent invocations ─────────────────────────────────
  property bool invocationActive: false

  // ────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────────────────────────────

  Component.onCompleted: {
    // Initialize runtime directory and run agent detection at startup.
    // This runs once when the shell loads the plugin, not on every activation.
    initProc.running = true
    detectAgentProc.running = true
  }

  // ── init: create runtime base and prune stale invocations ─────────────────

  Process {
    id: initProc
    running: false
    command: [root.helperScript, "init"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var base = text.trim()
        if (base) service.runtimeBase = base
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text.trim()) console.warn("scope/init:", text.trim())
      }
    }
    onExited: function(code) {
      if (code !== 0) console.warn("scope: helper init failed (exit " + code + ")")
    }
  }

  // ── agent detection ───────────────────────────────────────────────────────

  Process {
    id: detectAgentProc
    running: false
    command: [root.detectScript]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var agent = text.trim()
        root.detectedAgent = agent
        root.agentDetected = (agent === "codex" || agent === "claude")
        root.agentDetectionDone = true

        // If open() was called before detection finished, resume now
        if (root.scopeState === "Idle" && root.invocationActive) {
          root.invocationActive = false
          root.beginSelection()
        }
      }
    }
    onExited: function(code) {
      if (!root.agentDetectionDone) {
        root.detectedAgent = "none"
        root.agentDetected = false
        root.agentDetectionDone = true
        root.invocationActive = false
      }
    }
  }

  // ── response file reader ──────────────────────────────────────────────────

  FileView {
    id: responseReader
    path: ""
    watchChanges: false
    printErrors: false
    onLoaded: {
      root.responseText = text().trim()
      root.scopeState = "Complete"
    }
    onLoadFailed: root.showError("Failed to read agent response.")
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Public API (called by shell summon/hide machinery)
  // ────────────────────────────────────────────────────────────────────────────

  function open(payloadJson) {
    if (root.invocationActive) return

    if (!root.agentDetectionDone) {
      // Detection still running — mark intent, resume when done
      root.invocationActive = true
      return
    }

    root.beginSelection()
  }

  function close() {
    root.cancel()
  }

  function dismiss() {
    root.cancel()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  // ────────────────────────────────────────────────────────────────────────────
  // State transitions
  // ────────────────────────────────────────────────────────────────────────────

  function beginSelection() {
    // Clear previous state
    root.lassoPoints = []
    root.imageLassoPoints = []
    root.selectionX = 0
    root.selectionY = 0
    root.selectionW = 0
    root.selectionH = 0
    root.selectionScreen = null
    root.invocationId = ""
    root.capturedImagePath = ""
    root.responseText = ""
    root.errorText = ""
    root.invocationActive = true
    root.scopeState = "Selecting"
  }

  function onLassoComplete(points, bbox, screen) {
    if (root.scopeState !== "Selecting") return

    // Minimum selection size guard
    if (bbox.width < 16 || bbox.height < 16) {
      root.showError("Selection too small — try a larger area.")
      return
    }

    root.lassoPoints = points
    root.imageLassoPoints = bbox.imagePoints || []
    root.selectionX = bbox.x
    root.selectionY = bbox.y
    root.selectionW = bbox.width
    root.selectionH = bbox.height
    root.selectionScreen = screen
    root.scopeState = "Prompting"
  }

  function onQuestionSubmitted(question) {
    if (root.scopeState !== "Prompting") return
    if (!question || question.trim() === "") return
    if (question.length > 4096) {
      root.showError("Question is too long (max 4096 characters).")
      return
    }

    // Pass capture coordinates into the service before starting
    service.captureX = root.selectionX
    service.captureY = root.selectionY
    service.captureW = root.selectionW
    service.captureH = root.selectionH
    service.imageLassoPoints = root.imageLassoPoints

    root.scopeState = "Capturing"
    service.startCapture(question.trim())
  }

  function cancel() {
    if (root.scopeState === "Idle") return

    root.invocationActive = false
    root.scopeState = "Idle"
    root.lassoPoints = []
    root.responseText = ""
    root.errorText = ""

    if (root.invocationId !== "") {
      service.cleanupInvocation(root.invocationId)
      root.invocationId = ""
    }
  }

  function showError(msg) {
    root.errorText = msg
    root.invocationActive = false
    root.scopeState = "Idle"

    if (root.invocationId !== "") {
      service.cleanupInvocation(root.invocationId)
      root.invocationId = ""
    }

    errorClearTimer.restart()
  }

  // ── service callbacks ─────────────────────────────────────────────────────

  function onInvocationIdReady(id) {
    root.invocationId = id
  }

  function onCaptureSucceeded(imagePath) {
    root.capturedImagePath = imagePath
    root.scopeState = "AgentRunning"
    service.startAnalysis(imagePath)
  }

  function onCaptureFailed(msg) {
    root.showError(msg || "Screen capture failed.")
  }

  function onAnalysisSucceeded(responsePath) {
    responseReader.path = responsePath
    responseReader.reload()
  }

  function onAnalysisFailed(msg) {
    root.showError(msg || "Agent analysis failed.")
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Error toast timer
  // ────────────────────────────────────────────────────────────────────────────

  Timer {
    id: errorClearTimer
    interval: 5000
    repeat: false
    onTriggered: root.errorText = ""
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Service layer
  // ────────────────────────────────────────────────────────────────────────────

  ScopeService {
    id: service
    helperScript: root.helperScript
    runtimeBase: ""  // populated by initProc
    detectedAgent: root.detectedAgent

    // Capture inputs (set by onQuestionSubmitted before startCapture)
    captureX: 0
    captureY: 0
    captureW: 0
    captureH: 0
    imageLassoPoints: []

    onInvocationIdReady: function(id) { root.onInvocationIdReady(id) }
    onCaptureSucceeded: function(path) { root.onCaptureSucceeded(path) }
    onCaptureFailed: function(msg) { root.onCaptureFailed(msg) }
    onAnalysisSucceeded: function(path) { root.onAnalysisSucceeded(path) }
    onAnalysisFailed: function(msg) { root.onAnalysisFailed(msg) }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Screen overlays — one per connected screen
  // ────────────────────────────────────────────────────────────────────────────

  Variants {
    model: Quickshell.screens

    ScopeOverlay {
      required property var modelData
      screen: modelData

      scopeState: root.scopeState
      lassoPoints: root.lassoPoints
      selectionX: root.selectionX
      selectionY: root.selectionY
      selectionW: root.selectionW
      selectionH: root.selectionH
      selectionScreen: root.selectionScreen
      detectedAgent: root.detectedAgent
      agentDetected: root.agentDetected
      agentDetectionDone: root.agentDetectionDone
      responseText: root.responseText
      errorText: root.errorText

      onLassoComplete: function(points, bbox) {
        root.onLassoComplete(points, bbox, modelData)
      }
      onQuestionSubmitted: function(question) {
        root.onQuestionSubmitted(question)
      }
      onCancelled: root.cancel()
      onDismissed: root.dismiss()
    }
  }
}
