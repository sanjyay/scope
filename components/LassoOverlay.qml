// LassoOverlay — freehand lasso selection canvas.
//
// Captures mouse pointer events to build a freehand polygon path.
// Renders the path live using a Canvas (2D API) for smooth 60 FPS drawing.
//
// Signals:
//   complete(points, bbox)  — user released mouse with a valid selection
//   cancelled()             — user cancelled (Esc or right-click)
//
// points:  array of {x,y} in screen-absolute coordinates
// bbox:    {x, y, width, height, imagePoints} where:
//            x,y,width,height = screen-absolute bounding rect
//            imagePoints      = [{x,y}] relative to bounding box top-left
//                               (used for lasso masking)

import QtQuick

Item {
  id: root

  // Screen origin offset — converts window-relative mouse coords to screen-abs
  property real screenX: 0
  property real screenY: 0

  signal complete(var points, var bbox)
  signal cancelled()

  // ── internal state ────────────────────────────────────────────────────────

  property bool drawing: false
  property var rawPoints: []      // [{x,y}] window-relative, accumulated during drag
  property var closedPoints: []   // [{x,y}] after release (includes closure back to start)
  property bool hasSelection: false

  // Sampling: only record a point if we've moved >= threshold pixels.
  // This limits the array size without visually affecting the lasso shape.
  property real lastSampledX: 0
  property real lastSampledY: 0
  readonly property real sampleThreshold: 2.5

  // ── mouse input ───────────────────────────────────────────────────────────

  MouseArea {
    id: selectionArea
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: false
    cursorShape: Qt.CrossCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    preventStealing: true

    onPressed: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        root.cancelled()
        return
      }
      if (mouse.button !== Qt.LeftButton) return

      root.drawing = true
      root.hasSelection = false
      root.closedPoints = []
      root.rawPoints = [{ x: mouse.x, y: mouse.y }]
      root.lastSampledX = mouse.x
      root.lastSampledY = mouse.y
      lassoCanvas.requestPaint()
    }

    onPositionChanged: function(mouse) {
      if (!root.drawing) return

      var dx = mouse.x - root.lastSampledX
      var dy = mouse.y - root.lastSampledY
      if (dx * dx + dy * dy < root.sampleThreshold * root.sampleThreshold) return

      // Append point (create new array to trigger QML binding refresh)
      var pts = root.rawPoints.slice()
      pts.push({ x: mouse.x, y: mouse.y })
      root.rawPoints = pts
      root.lastSampledX = mouse.x
      root.lastSampledY = mouse.y
      lassoCanvas.requestPaint()
    }

    onReleased: function(mouse) {
      if (!root.drawing || mouse.button !== Qt.LeftButton) return
      root.drawing = false

      var pts = root.rawPoints
      if (pts.length < 3) {
        root.rawPoints = []
        lassoCanvas.requestPaint()
        return
      }

      // Close the polygon
      var closed = pts.concat([pts[0]])
      root.closedPoints = closed
      root.hasSelection = true
      lassoCanvas.requestPaint()

      // Calculate bounding box (window-relative)
      var minX = pts[0].x, maxX = pts[0].x
      var minY = pts[0].y, maxY = pts[0].y
      for (var i = 1; i < pts.length; i++) {
        if (pts[i].x < minX) minX = pts[i].x
        if (pts[i].x > maxX) maxX = pts[i].x
        if (pts[i].y < minY) minY = pts[i].y
        if (pts[i].y > maxY) maxY = pts[i].y
      }

      // Screen-absolute points
      var absPoints = pts.map(function(p) {
        return { x: Math.round(p.x + root.screenX), y: Math.round(p.y + root.screenY) }
      })

      // Image-relative points (relative to bounding box top-left)
      var imagePoints = pts.map(function(p) {
        return { x: Math.round(p.x - minX), y: Math.round(p.y - minY) }
      })

      var bbox = {
        x: Math.round(minX + root.screenX),
        y: Math.round(minY + root.screenY),
        width: Math.max(1, Math.round(maxX - minX)),
        height: Math.max(1, Math.round(maxY - minY)),
        imagePoints: imagePoints
      }

      root.complete(absPoints, bbox)
    }
  }

  // ── canvas renderer ───────────────────────────────────────────────────────

  Canvas {
    id: lassoCanvas
    anchors.fill: parent
    visible: root.drawing || root.hasSelection
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)

      var pts = root.drawing ? root.rawPoints : root.closedPoints
      if (pts.length < 2) return

      ctx.save()

      // ── filled region ──────────────────────────────────────────────────
      ctx.beginPath()
      ctx.moveTo(pts[0].x, pts[0].y)
      for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y)
      ctx.closePath()
      ctx.fillStyle = "rgba(255, 255, 255, 0.06)"
      ctx.fill()

      // ── outer glow stroke ──────────────────────────────────────────────
      ctx.beginPath()
      ctx.moveTo(pts[0].x, pts[0].y)
      for (var j = 1; j < pts.length; j++) ctx.lineTo(pts[j].x, pts[j].y)
      if (!root.drawing) ctx.closePath()

      ctx.strokeStyle = "rgba(255, 255, 255, 0.18)"
      ctx.lineWidth = 6
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.stroke()

      // ── main stroke ────────────────────────────────────────────────────
      ctx.beginPath()
      ctx.moveTo(pts[0].x, pts[0].y)
      for (var k = 1; k < pts.length; k++) ctx.lineTo(pts[k].x, pts[k].y)
      if (!root.drawing) ctx.closePath()

      ctx.strokeStyle = "rgba(255, 255, 255, 0.88)"
      ctx.lineWidth = 1.75
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.stroke()

      // ── start-point dot ────────────────────────────────────────────────
      ctx.beginPath()
      ctx.arc(pts[0].x, pts[0].y, 5, 0, Math.PI * 2)
      ctx.fillStyle = "rgba(255, 255, 255, 0.95)"
      ctx.fill()

      // ── closing hint: proximity ring near start when drawing ───────────
      if (root.drawing && pts.length > 5) {
        var last = pts[pts.length - 1]
        var dx = last.x - pts[0].x
        var dy = last.y - pts[0].y
        var dist = Math.sqrt(dx * dx + dy * dy)
        if (dist < 40) {
          // Pulse the start dot to hint the user can close here
          var alpha = 0.3 + 0.5 * (1 - dist / 40)
          ctx.beginPath()
          ctx.arc(pts[0].x, pts[0].y, 12, 0, Math.PI * 2)
          ctx.strokeStyle = "rgba(255, 255, 255, " + alpha + ")"
          ctx.lineWidth = 1.5
          ctx.stroke()
        }
      }

      ctx.restore()
    }
  }

  // ── keyboard ──────────────────────────────────────────────────────────────

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      event.accepted = true
      root.drawing = false
      root.rawPoints = []
      root.closedPoints = []
      root.hasSelection = false
      lassoCanvas.requestPaint()
      root.cancelled()
    }
  }
}
