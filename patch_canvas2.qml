--- components/LassoOverlay.qml
+++ components/LassoOverlay.qml
@@ -158,35 +158,26 @@
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
 
-      var drawPath = function(close) {
-        ctx.beginPath()
-        ctx.moveTo(pts[0].x, pts[0].y)
-        for (var i = 1; i < pts.length; i++) {
-          ctx.lineTo(pts[i].x, pts[i].y)
-        }
-        if (root.drawing && root.currentPointerPoint) {
-          ctx.lineTo(root.currentPointerPoint.x, root.currentPointerPoint.y)
-        }
-        if (close) ctx.closePath()
-      }
-
-      // ── filled region ──────────────────────────────────────────────────
-      if (!root.drawing) {
-        drawPath(true)
-        ctx.fillStyle = Color.accent
-        ctx.globalAlpha = 0.10
-        ctx.fill()
-        ctx.globalAlpha = 1
+      ctx.beginPath()
+      ctx.moveTo(pts[0].x, pts[0].y)
+      for (var i = 1; i < pts.length; i++) {
+        ctx.lineTo(pts[i].x, pts[i].y)
+      }
+      if (root.drawing && root.currentPointerPoint) {
+        ctx.lineTo(root.currentPointerPoint.x, root.currentPointerPoint.y)
       }
+      // We never closePath during drawing.
+      // If !root.drawing, pts is closedPoints which already contains the first point at the end, so it visually closes!
 
       // ── outer glow stroke ──────────────────────────────────────────────
-      drawPath(!root.drawing)
       ctx.strokeStyle = Color.imagePicker.unselectedBorder
       ctx.lineWidth = Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.20))
       ctx.lineJoin = "round"
       ctx.lineCap = "round"
       ctx.stroke()
 
       // ── main stroke ────────────────────────────────────────────────────
-      drawPath(!root.drawing)
       ctx.strokeStyle = Color.imagePicker.selectedBorder
       ctx.lineWidth = 1.75
       ctx.lineJoin = "round"
       ctx.lineCap = "round"
       ctx.stroke()
 
       ctx.restore()
