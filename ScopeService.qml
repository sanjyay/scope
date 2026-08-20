// ScopeService — secure process runner for capture and Scope Search.
//
// Manages the 5-step pipeline:
//   1. Generate random invocation ID
//   2. Create invocation directory (mkdir -p, 0700)
//   3. Write lasso points file (from QML properties, no shell interpolation)
//   4. Invoke scope-helper capture (grim + lasso mask)
//   5. Invoke scope-helper search (protected agent adapter)
//
// All subprocess invocations use structured argument arrays.
// No user content is ever interpolated into shell strings.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  // ── configuration ─────────────────────────────────────────────────────────
  required property string helperScript
  required property string runtimeBase
  required property string detectedAgent

  // ── capture inputs (set by parent before calling startCapture) ────────────
  property var lassoPoints: []         // [{x,y}] in screen-absolute coords
  property var imageLassoPoints: []    // [{x,y}] in image-relative coords
  property int captureX: 0
  property int captureY: 0
  property int captureW: 0
  property int captureH: 0

  // ── signals ───────────────────────────────────────────────────────────────
  signal captureSucceeded(string imagePath)
  signal captureFailed(string message)
  signal analysisSucceeded(string responsePath)
  signal analysisFailed(string message)
  signal invocationIdReady(string id)
  signal escalationSucceeded()
  signal escalationFailed(string message)

  // ── pipeline state ────────────────────────────────────────────────────────
  property string currentInvId: ""
  property string pendingQuestion: ""
  property string pendingImagePath: ""
  property string targetAction: "web_search"
  property int activeGeneration: 0
  property bool workCancelled: false

  // ────────────────────────────────────────────────────────────────────────────
  // Public API
  // ────────────────────────────────────────────────────────────────────────────

  function startCapture(question) {
    root.workCancelled = false
    root.pendingQuestion = question
    root.currentInvId = ""
    idGenProc.running = true
  }

  function escalate(invId, imagePath) {
    if (!invId || !/^[0-9a-f]{16}$/.test(invId)) {
      root.escalationFailed("Couldn't open Codex.")
      return
    }
    var qPath = root.runtimeBase + "/" + invId + "/question.txt"
    var p = escalateProcComp.createObject(root, {
      command: [
        root.helperScript, "escalate",
        invId,
        imagePath,
        qPath,
        root.detectedAgent
      ]
    })
    if (p) p.running = true
    else root.escalationFailed("Couldn't open Codex.")
  }

  Component {
    id: escalateProcComp
    Process {
      id: escalateProc
      running: false
      property bool reported: false
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          if (text.trim() === "OK") {
            root.escalationSucceeded()
          } else {
            root.escalationFailed("Couldn't open Codex.")
          }
          escalateProc.reported = true
        }
      }
      onExited: function(code) {
        if (!reported && code !== 0) root.escalationFailed("Couldn't open Codex.")
        this.destroy()
      }
    }
  }

  function searchWeb(imagePath, question) {
    root.workCancelled = false
    root.pendingImagePath = imagePath
    var qPath = root.runtimeBase + "/" + root.currentInvId + "/question.txt"
    questionWriterProc.targetPath = qPath
    root.targetAction = "web_search"
    questionWriterProc.textData = question; questionWriterProc.running = true
  }

  function runSearch() {
    var qPath = root.runtimeBase + "/" + root.currentInvId + "/question.txt"

    if (root.detectedAgent !== "codex") {
      root.analysisFailed("Scope currently supports Codex only.")
      return
    }

    analyzeProc.command = [
      root.helperScript, "search",
      root.currentInvId,
      root.pendingImagePath,
      qPath,
      root.detectedAgent
    ]
    analyzeProc.running = true
  }

  function cancelWork() {
    // Terminating the helper immediately triggers its scoped child/process-group
    // cleanup. Never use a global codex kill: other user sessions are unrelated.
    root.workCancelled = true
    // Quickshell's Process cancellation API is `running = false`; it sends
    // SIGTERM to this Scope-owned helper, whose trap handles its child group.
    if (idGenProc.running) idGenProc.running = false
    if (mkdirProc.running) mkdirProc.running = false
    if (pointsWriterProc.running) pointsWriterProc.running = false
    if (questionWriterProc.running) questionWriterProc.running = false
    if (captureProc.running) captureProc.running = false
    if (analyzeProc.running) analyzeProc.running = false
  }

  function cleanupInvocation(invId) {
    if (!invId || !/^[0-9a-f]{16}$/.test(invId)) return
    var p = cleanupProcComp.createObject(root, {
      command: [root.helperScript, "cleanup", invId]
    })
    if (p) p.running = true
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 1: Generate cryptographically random invocation ID
  // ────────────────────────────────────────────────────────────────────────────

  Process {
    id: idGenProc
    running: false
    command: ["bash", "-c",
      "dd if=/dev/urandom bs=8 count=1 2>/dev/null | od -A n -t x1 | tr -d ' \\n'"
    ]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.workCancelled) return
        var id = text.trim()
        if (!/^[0-9a-f]{16}$/.test(id)) {
          root.captureFailed("Failed to generate invocation ID.")
          return
        }
        root.currentInvId = id
        root.invocationIdReady(id)
        root.createInvocationDir()
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.workCancelled) return
        if (text.trim()) console.warn("scope/idgen stderr:", text.trim())
      }
    }
    onExited: function(code) {
      if (root.workCancelled) return
      if (code !== 0 && root.currentInvId === "")
        root.captureFailed("ID generation failed (exit " + code + ").")
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 2: Create invocation directory
  // ────────────────────────────────────────────────────────────────────────────

  function createInvocationDir() {
    var invDir = root.runtimeBase + "/" + root.currentInvId
    mkdirProc.command = [
      "bash", "-c",
      // Validate the path before mkdir (defense-in-depth alongside helper)
      "d=$0; b=$1; r=$(realpath -m -- \"$d\" 2>/dev/null); " +
      "[[ $r == $b/* ]] || exit 1; " +
      "mkdir -p \"$d\" && chmod 700 \"$d\" && echo ok",
      invDir, root.runtimeBase
    ]
    mkdirProc.running = true
  }

  Process {
    id: mkdirProc
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.workCancelled) return
        if (text.trim() !== "ok") {
          root.captureFailed("Failed to create invocation directory.")
          return
        }
        root.writePointsFile()
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.workCancelled) return
        if (text.trim()) console.warn("scope/mkdir stderr:", text.trim())
      }
    }
    onExited: function(code) {
      if (root.workCancelled) return
      if (code !== 0 && mkdirProc.stdout.text.trim() !== "ok")
        root.captureFailed("mkdir failed (exit " + code + ").")
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 3: Write lasso points to private temp file
  // ────────────────────────────────────────────────────────────────────────────

  // Points file path
  property string pointsFilePath: ""

  function writePointsFile() {
    var pPath = root.runtimeBase + "/" + root.currentInvId + "/points.txt"
    root.pointsFilePath = pPath

    // Build points string from imageLassoPoints: "x,y x,y x,y ..."
    // imageLassoPoints are relative to bounding box origin
    var pts = root.imageLassoPoints
    var parts = []
    for (var i = 0; i < pts.length; i++) {
      parts.push(Math.round(pts[i].x) + "," + Math.round(pts[i].y))
    }
    var pointsData = parts.join(" ")

    pointsWriterProc.targetPath = pPath
    pointsWriterProc.textData = pointsData; pointsWriterProc.running = true
  }

  Process {
    id: pointsWriterProc
    running: false
    property string textData: ""
    property string targetPath: ""
    command: ["bash", "-c", 'printf "%s" "$1" > "$2"', "--", textData, targetPath]
    onExited: { if (!root.workCancelled) root.runCapture() }
  }


  // ────────────────────────────────────────────────────────────────────────────
  // Step 4: Run scope-helper capture
  // ────────────────────────────────────────────────────────────────────────────

  function runCapture() {
    captureProc.command = [
      root.helperScript, "capture",
      root.currentInvId,
      String(Math.round(root.captureX)),
      String(Math.round(root.captureY)),
      String(Math.max(1, Math.round(root.captureW))),
      String(Math.max(1, Math.round(root.captureH))),
      root.pointsFilePath
    ]
    captureProc.running = true
  }

  Process {
    id: captureProc
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.workCancelled) return
        var path = text.trim()
        if (!path) return  // Exit handler will report error
        if (path.startsWith("ERROR:")) {
          root.captureFailed(path.substring(7).trim() || "Screen capture failed.")
          return
        }
        // Validate path is inside our runtime dir
        if (!path.startsWith(root.runtimeBase + "/")) {
          root.captureFailed("Capture returned invalid path.")
          return
        }
        root.captureSucceeded(path)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.workCancelled) return
        if (text.trim()) console.warn("scope/capture stderr:", text.trim())
      }
    }
    onExited: function(code) {
      if (root.workCancelled) return
      if (code !== 0) {
        var out = captureProc.stdout ? captureProc.stdout.text.trim() : ""
        if (!out || out.startsWith("ERROR:")) {
          root.captureFailed("Screen capture failed (exit " + code + ").")
        }
      }
    }
  }

  Process {
    id: questionWriterProc
    running: false
    property string textData: ""
    property string targetPath: ""
    command: ["bash", "-c", 'printf "%s" "$1" > "$2"', "--", textData, targetPath]
    onExited: {
      if (!root.workCancelled && root.targetAction === "web_search") root.runSearch()
    }
  }


  Process {
    id: analyzeProc
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.workCancelled) return
        var path = text.trim()
        if (!path) return  // Exit handler will report
        if (path.startsWith("ERROR:")) {
          root.analysisFailed(path.substring(7).trim() || "Agent analysis failed.")
          return
        }
        if (!path.startsWith(root.runtimeBase + "/")) {
          root.analysisFailed("Analysis returned invalid path.")
          return
        }
        root.analysisSucceeded(path)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.workCancelled) return
        if (text.trim()) console.warn("scope/analyze stderr:", text.trim())
      }
    }
    onExited: function(code) {
      if (root.workCancelled) return
      if (code !== 0) {
        var out = analyzeProc.stdout ? analyzeProc.stdout.text.trim() : ""
        if (!out || out.startsWith("ERROR:")) {
          root.analysisFailed("Agent analysis failed (exit " + code + ").")
        }
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Cleanup process template
  // ────────────────────────────────────────────────────────────────────────────

  Component {
    id: cleanupProcComp
    Process {
      running: false
      onExited: destroy()
      stderr: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          if (text.trim()) console.warn("scope/cleanup:", text.trim())
        }
      }
    }
  }
}
