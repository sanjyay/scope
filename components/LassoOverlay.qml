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

  onEnabledChanged: { if (!enabled) { root.drawing = false; root.hasSelection = false; root.rawPoints = []; root.closedPoints = []; root.currentPointerPoint = null; lassoCanvas.requestPaint(); } }

  signal complete(var points, var bbox)
  signal cancelled()

  // ── internal state ────────────────────────────────────────────────────────

  property bool drawing: false
  property var rawPoints: []      // [{x,y}] window-relative, accumulated during drag
  property var closedPoints: []   // [{x,y}] after release (includes closure back to start)
  property bool hasSelection: false
  property var currentPointerPoint: null // {x,y} live tail point

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
      root.currentPointerPoint = { x: mouse.x, y: mouse.y }
      root.minX = root.maxX = mouse.x
      root.minY = root.maxY = mouse.y
      root.lastSampledX = mouse.x
      root.lastSampledY = mouse.y
      lassoCanvas.requestPaint()
    }

    onPositionChanged: function(mouse) {
      if (!root.drawing) return

      // Always update live tail and request a paint
      root.currentPointerPoint = { x: mouse.x, y: mouse.y }

      var dx = mouse.x - root.lastSampledX
      var dy = mouse.y - root.lastSampledY
      if (dx * dx + dy * dy >= root.sampleThreshold * root.sampleThreshold) {
        // Keep the capture path mutable; never clone an ever-growing array.
        root.rawPoints.push({ x: mouse.x, y: mouse.y })
        root.minX = Math.min(root.minX, mouse.x); root.maxX = Math.max(root.maxX, mouse.x)
        root.minY = Math.min(root.minY, mouse.y); root.maxY = Math.max(root.maxY, mouse.y)
        root.lastSampledX = mouse.x
        root.lastSampledY = mouse.y
      }
      
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
      if (pts.length === 0) return

      ctx.save()

      ctx.beginPath()
      ctx.moveTo(pts[0].x, pts[0].y)
      for (var i = 1; i < pts.length; i++) {
        ctx.lineTo(pts[i].x, pts[i].y)
      }
      if (root.drawing && root.currentPointerPoint) {
        ctx.lineTo(root.currentPointerPoint.x, root.currentPointerPoint.y)
      }

      // ── outer glow stroke ──────────────────────────────────────────────
      ctx.strokeStyle = Color.imagePicker.unselectedBorder
      ctx.lineWidth = Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.20))
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.stroke()

      // ── main stroke ────────────────────────────────────────────────────
      ctx.strokeStyle = Color.imagePicker.selectedBorder
      ctx.lineWidth = 1.75
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.stroke()

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
      root.currentPointerPoint = null
      root.hasSelection = false
      lassoCanvas.requestPaint()
      root.cancelled()
    }
  }
}
