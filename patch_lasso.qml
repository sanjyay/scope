--- components/LassoOverlay.qml
+++ components/LassoOverlay.qml
@@ -23,7 +23,7 @@
   property real screenX: 0
   property real screenY: 0
 
-  onEnabledChanged: { if (!enabled) { root.drawing = false; root.hasSelection = false; root.rawPoints = []; root.closedPoints = []; root.currentPointerPoint = null; lassoCanvas.requestPaint(); } }
+  onEnabledChanged: { if (!enabled) { root.drawing = false; root.hasSelection = false; root.finalOutlineVisible = false; outlineTimer.stop(); root.rawPoints = []; root.closedPoints = []; root.currentPointerPoint = null; lassoCanvas.requestPaint(); } }
 
   signal complete(var points, var bbox)
   signal cancelled()
@@ -37,6 +37,16 @@
   property real maxX: 0
   property real maxY: 0
   readonly property real sampleThreshold: 2.5
+  
+  property bool finalOutlineVisible: false
+  
+  Timer {
+    id: outlineTimer
+    interval: 3000
+    repeat: false
+    onTriggered: { root.finalOutlineVisible = false; lassoCanvas.requestPaint() }
+  }
 
   // ── mouse input ───────────────────────────────────────────────────────────
 
@@ -123,6 +133,8 @@
       var closed = pts.concat([pts[0]])
       root.closedPoints = closed
       root.hasSelection = true
+      root.finalOutlineVisible = true
+      outlineTimer.restart()
       lassoCanvas.requestPaint()
 
       // Calculate bounding box (window-relative)
@@ -158,7 +170,7 @@
   Canvas {
     id: lassoCanvas
     anchors.fill: parent
-    visible: root.drawing || root.hasSelection
+    visible: root.drawing || root.finalOutlineVisible
     antialiasing: true
 
     onPaint: {
@@ -179,15 +191,9 @@
         if (root.drawing && root.currentPointerPoint) {
           ctx.lineTo(root.currentPointerPoint.x, root.currentPointerPoint.y)
         }
-        if (close) ctx.closePath()
+        if (close) { ctx.lineTo(pts[0].x, pts[0].y) }
       }
 
-      // ── filled region ──────────────────────────────────────────────────
-      if (!root.drawing) {
-        drawPath(true)
-        ctx.fillStyle = Color.accent
-        ctx.globalAlpha = 0.10
-        ctx.fill()
-        ctx.globalAlpha = 1
-      }
-
       // ── outer glow stroke ──────────────────────────────────────────────
