// Scope — circle anything, search anything.
//
// Entry point for the "overlay" kind. keepLoaded: true so the surface is
// available instantly on hotkey without load latency.
//
// State machine:
//   Idle → Selecting → Capturing → Searching → Result
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
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || ""
  readonly property string pluginId: "goblin.scope"

  // The plugin dir is determined at install time.
  // Scripts are located relative to the manifest, which is our plugin dir.
  // In Quickshell, Qt.resolvedUrl(".") gives the dir of the QML file.
  readonly property string pluginDir: {
    var urlStr = Qt.resolvedUrl(".").toString()
    // Strip file:// prefix
    return urlStr.replace(/^file:\/\//, "").replace(/\/$/, "")
  }
  readonly property string helperScript: pluginDir + "/scripts/scope-helper"
  readonly property string detectScript: pluginDir + "/scripts/scope-detect-agent"

  // ── state machine ─────────────────────────────────────────────────────────
  // "Idle" | "Selecting" | "Capturing" | "Searching" | "Result" | "UnsupportedAgent"
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
  property var webSources: []
  property string pendingQuestion: ""
  property string latestFollowUp: ""
  property int responseGeneration: -1
  property bool escalationPending: false
  property int agentFreshGeneration: -1
  property bool pendingSearchAfterAgentRefresh: false

  readonly property string defaultSearchIntent:
    "Identify what is visible in this selected image. Search the web when useful and give the most relevant concise information with reliable sources."


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

  Process {
    id: refreshAgentProc
    running: false
    command: [root.detectScript]
    property int generation: -1
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (refreshAgentProc.generation !== root.sessionGeneration) return
        var agent = text.trim()
        root.detectedAgent = agent
        root.agentDetected = (agent === "codex")
        root.agentDetectionDone = true
        root.agentFreshGeneration = root.sessionGeneration
        if (!root.agentDetected) {
          root.pendingSearchAfterAgentRefresh = false
          root.scopeState = "UnsupportedAgent"
          return
        }
        if (root.pendingSearchAfterAgentRefresh) {
          root.pendingSearchAfterAgentRefresh = false
          root.startInitialSearch()
        }
      }
    }
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
        root.agentDetected = (agent === "codex")
        root.agentDetectionDone = true

        // If open() was called before startup detection finished, begin the
        // normal per-invocation refresh path rather than trusting this result.
        if (root.scopeState === "Idle" && root.invocationActive) {
          root.invocationActive = false
          root.open()
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
      var raw = text().trim()
      if (root.responseGeneration !== root.sessionGeneration || root.scopeState === "Idle") return
      if (raw.startsWith("{")) {
        try {
          var data = JSON.parse(raw)
          root.responseText = data.answer || "No answer returned."
          root.webSources = root.safeSources(data.sources || [])
        } catch(e) {
          root.responseText = "Failed to parse search results."
          root.webSources = []
        }
      } else {
        root.responseText = raw || "No response received."
        root.webSources = []
      }
      root.scopeState = "Result"
    }
    onLoadFailed: {
      if (root.responseGeneration === root.sessionGeneration && root.scopeState !== "Idle")
        root.showError("Failed to read agent response.")
    }
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

    root.resetSession()
    root.invocationActive = true
    root.scopeState = "Selecting"
    refreshAgentProc.generation = root.sessionGeneration
    refreshAgentProc.running = true
  }

  function close() {
    root.cancelSession()
  }

  function dismiss() {
    root.cancelSession()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  // ────────────────────────────────────────────────────────────────────────────
  // State transitions
  // ────────────────────────────────────────────────────────────────────────────


  property int sessionGeneration: 0

  function resetSession() {
    root.invocationActive = false
    root.scopeState = "Idle"

    root.lassoPoints = []
    root.imageLassoPoints = []
    root.selectionX = 0
    root.selectionY = 0
    root.selectionW = 0
    root.selectionH = 0
    root.selectionScreen = null

    root.capturedImagePath = ""
    root.responseText = ""
    root.errorText = ""
    root.webSources = []
    root.pendingQuestion = ""
    root.latestFollowUp = ""
    root.pendingSearchAfterAgentRefresh = false
    root.responseGeneration = -1
    root.escalationPending = false

    root.sessionGeneration += 1
    if (refreshAgentProc.running) refreshAgentProc.running = false
    service.cancelWork()

    if (root.invocationId !== "") {
      service.cleanupInvocation(root.invocationId)
      root.invocationId = ""
    }
  }

  function safeSources(sources) {
    var safe = []
    var seen = ({})
    if (!Array.isArray(sources)) return safe
    for (var i = 0; i < sources.length; i++) {
      var source = sources[i] || ({})
      var url = root.safeWebUrl(source.url)
      if (!url || seen[url]) continue
      seen[url] = true
      safe.push({
        title: typeof source.title === "string" && source.title.trim()
          ? source.title.replace(/\s+/g, " ").trim().slice(0, 240) : "",
        url: url
      })
    }
    return safe
  }

  // Search output is untrusted remote data. Normalize only ordinary HTTP(S)
  // URLs, then ResultCard validates again at the browser-launch boundary.
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


  function escalateSession() {
    if (root.scopeState !== "Result" || root.escalationPending ||
        !root.invocationId || !root.capturedImagePath) return
    root.escalationPending = true
    service.escalate(root.invocationId, root.capturedImagePath)
  }

  function onEscalationSucceeded() {
    if (!root.escalationPending) return
    // The helper has copied the selected image/context and confirmed that the
    // user-owned interactive launcher started. Reset Scope now; its cleanup
    // only owns protected capture/search jobs, never interactive Codex.
    root.completeEscalation()
  }

  function completeEscalation() {
    root.resetSession()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  function onEscalationFailed(message) {
    root.escalationPending = false
    // Preserve the visible result: the user can retry Open Agent or close it.
    root.errorText = message || "Couldn't open Codex."
    errorClearTimer.restart()
  }

  function onSourceOpenFailed() {
    // Browser-launch failures should not discard the current result.
    root.errorText = "Couldn't open source."
    errorClearTimer.restart()
  }

  function cancelSession() {
    if (root.scopeState === "Idle") return
    resetSession()
  }

  function beginSelection() {
    // Replaced by resetSession()
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
    if (root.agentFreshGeneration !== root.sessionGeneration) {
      root.pendingSearchAfterAgentRefresh = true
      return
    }
    root.startInitialSearch()
  }

  function configureCapture() {

    service.captureX = root.selectionX
    service.captureY = root.selectionY
    service.captureW = root.selectionW
    service.captureH = root.selectionH
    service.imageLassoPoints = root.imageLassoPoints

  }

  function startInitialSearch() {
    if (root.scopeState !== "Selecting") return
    // Never use a stale/default provider from an earlier Scope invocation.
    // Codex is the sole protected visual-search backend for this build.
    if (root.agentFreshGeneration !== root.sessionGeneration ||
        root.detectedAgent !== "codex") {
      root.scopeState = "UnsupportedAgent"
      return
    }
    root.configureCapture()
    root.pendingQuestion = root.defaultSearchIntent
    root.scopeState = "Capturing"
    service.activeGeneration = root.sessionGeneration
    service.startCapture(root.pendingQuestion)
  }

  function onFollowUpSubmitted(question) {
    if (root.scopeState !== "Result" || !root.capturedImagePath) return
    var trimmed = question ? question.trim() : ""
    if (!trimmed) return
    root.pendingQuestion = trimmed
    root.latestFollowUp = trimmed
    root.responseText = ""
    root.webSources = []
    root.scopeState = "Searching"
    service.activeGeneration = root.sessionGeneration
    service.searchWeb(root.capturedImagePath, trimmed)
  }




  function showError(msg) {
    root.errorText = msg
    root.invocationActive = false
    root.scopeState = "Error"

    if (root.invocationId !== "") {
      service.cleanupInvocation(root.invocationId)
      root.invocationId = ""
    }

    errorClearTimer.restart()
  }

  // ── service callbacks ─────────────────────────────────────────────────────

  function onInvocationIdReady(id) {
    if (service.activeGeneration !== root.sessionGeneration) return

    root.invocationId = id
  }


  function onCaptureSucceeded(imagePath) {
    if (service.activeGeneration !== root.sessionGeneration) return
    root.capturedImagePath = imagePath

    root.scopeState = "Searching"
    service.searchWeb(imagePath, root.pendingQuestion)
  }


  function onCaptureFailed(msg) {
    if (service.activeGeneration !== root.sessionGeneration) return

    root.showError(msg || "Screen capture failed.")
  }

  function onAnalysisSucceeded(responsePath) {
    if (service.activeGeneration !== root.sessionGeneration) return

    root.responseGeneration = root.sessionGeneration
    responseReader.path = responsePath
    responseReader.reload()
  }

  function onAnalysisFailed(msg) {
    if (service.activeGeneration !== root.sessionGeneration) return

    root.showError(msg || "Agent analysis failed.")
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Error toast timer
  // ────────────────────────────────────────────────────────────────────────────

  Timer {
    id: errorClearTimer
    interval: 5000
    repeat: false
    onTriggered: {
      if (root.scopeState === "Error") root.dismiss()
      else root.errorText = ""
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Service layer
  // ────────────────────────────────────────────────────────────────────────────

  ScopeService {
    id: service
    helperScript: root.helperScript
    runtimeBase: ""  // populated by initProc
    detectedAgent: root.detectedAgent

    // Capture inputs are set from the completed lasso before Scope Search.
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
    onEscalationSucceeded: root.onEscalationSucceeded()
    onEscalationFailed: function(msg) { root.onEscalationFailed(msg) }
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
      webSources: root.webSources
      errorText: root.errorText
      pendingQuestion: root.pendingQuestion
      escalationPending: root.escalationPending
      onLassoComplete: function(points, bbox) {
        root.onLassoComplete(points, bbox, modelData)
      }
      onFollowUpSubmitted: function(question) { root.onFollowUpSubmitted(question) }
      onRequestOpenAgent: root.escalateSession()
      onSourceOpenFailed: root.onSourceOpenFailed()
      onCancelled: root.cancelSession()
      onDismissed: root.dismiss()
    }
  }
}
