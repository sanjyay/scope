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
import qs.Commons

Item {
  id: root

  // Screen origin offset — converts window-relative mouse coords to screen-abs
  property real screenX: 0
  property real screenY: 0

  signal complete(var points, var bbox)
  signal cancelled()
  onEnabledChanged: { if (!enabled) { root.drawing = false; root.hasSelection = false; root.rawPoints = []; root.closedPoints = []; lassoCanvas.requestPaint(); } }

  // ── internal state ────────────────────────────────────────────────────────

  property bool drawing: false
  property var rawPoints: []      // [{x,y}] window-relative, accumulated during drag
  property var closedPoints: []   // [{x,y}] after release (includes closure back to start)
  property bool hasSelection: false

  // Sampling: only record a point if we've moved >= threshold pixels.
  // This limits the array size without visually affecting the lasso shape.
  property real lastSampledX: 0
  property real lastSampledY: 0
  property real minX: 0
  property real minY: 0
  property real maxX: 0
  property real maxY: 0
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
      root.minX = root.maxX = mouse.x
      root.minY = root.maxY = mouse.y
      root.lastSampledX = mouse.x
      root.lastSampledY = mouse.y
      lassoCanvas.requestPaint()
    }

    onPositionChanged: function(mouse) {
      if (!root.drawing) return

      var dx = mouse.x - root.lastSampledX
      var dy = mouse.y - root.lastSampledY
      if (dx * dx + dy * dy < root.sampleThreshold * root.sampleThreshold) return

      // Keep the capture path mutable; never clone an ever-growing array.
      root.rawPoints.push({ x: mouse.x, y: mouse.y })
      root.minX = Math.min(root.minX, mouse.x); root.maxX = Math.max(root.maxX, mouse.x)
      root.minY = Math.min(root.minY, mouse.y); root.maxY = Math.max(root.maxY, mouse.y)
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
      var minX = root.minX, maxX = root.maxX
      var minY = root.minY, maxY = root.maxY

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

      var drawSmoothPath = function(close) {
        ctx.beginPath()
        ctx.moveTo(pts[0].x, pts[0].y)
        if (pts.length < 3) {
          for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y)
        } else {
          for (var i = 1; i < pts.length - 1; i++) {
            var xc = (pts[i].x + pts[i+1].x) / 2
            var yc = (pts[i].y + pts[i+1].y) / 2
            ctx.quadraticCurveTo(pts[i].x, pts[i].y, xc, yc)
          }
          ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y)
        }
        if (close) ctx.closePath()
      }

      // ── filled region ──────────────────────────────────────────────────
      drawSmoothPath(true)
      ctx.fillStyle = Color.accent
      ctx.globalAlpha = 0.10
      ctx.fill()
      ctx.globalAlpha = 1

      // ── outer glow stroke ──────────────────────────────────────────────
      drawSmoothPath(!root.drawing)
      ctx.strokeStyle = Color.imagePicker.unselectedBorder
      ctx.lineWidth = Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.20))
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.stroke()

      // ── main stroke ────────────────────────────────────────────────────
      drawSmoothPath(!root.drawing)
      ctx.strokeStyle = Color.imagePicker.selectedBorder
      ctx.lineWidth = 1.75
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.stroke()

      // ── start-point dot ────────────────────────────────────────────────
      ctx.beginPath()
      ctx.arc(pts[0].x, pts[0].y, 5, 0, Math.PI * 2)
      ctx.fillStyle = Color.imagePicker.selectedBorder
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
          ctx.strokeStyle = Color.imagePicker.selectedBorder
          ctx.globalAlpha = alpha
          ctx.lineWidth = Math.max(Style.spacing.hairline, Style.space(2))
          ctx.stroke()
          ctx.globalAlpha = 1
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
