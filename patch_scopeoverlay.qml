--- ScopeOverlay.qml
+++ ScopeOverlay.qml
@@ -107,6 +107,52 @@
     onCancelled: panel.cancelled()
   }
 
+  // ── final selection outline ───────────────────────────────────────────────
+
+  property var finalOutlinePoints: []
+  property bool finalOutlineVisible: false
+
+  Timer {
+    id: finalOutlineTimer
+    interval: 3000
+    repeat: false
+    onTriggered: {
+      panel.finalOutlineVisible = false
+      panel.finalOutlinePoints = []
+      finalOutlineCanvas.requestPaint()
+    }
+  }
+
+  Canvas {
+    id: finalOutlineCanvas
+    anchors.fill: parent
+    visible: panel.isActiveScreen && panel.finalOutlineVisible
+    antialiasing: true
+
+    onPaint: {
+      var ctx = getContext("2d")
+      ctx.clearRect(0, 0, width, height)
+      var pts = panel.finalOutlinePoints
+      if (!pts || pts.length === 0) return
+
+      ctx.save()
+      ctx.beginPath()
+      ctx.moveTo(pts[0].x, pts[0].y)
+      for (var i = 1; i < pts.length; i++) {
+        ctx.lineTo(pts[i].x, pts[i].y)
+      }
+
+      ctx.strokeStyle = Color.imagePicker.unselectedBorder
+      ctx.lineWidth = Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.20))
+      ctx.lineJoin = "round"
+      ctx.lineCap = "round"
+      ctx.stroke()
+
+      ctx.strokeStyle = Color.imagePicker.selectedBorder
+      ctx.lineWidth = 1.75
+      ctx.lineJoin = "round"
+      ctx.lineCap = "round"
+      ctx.stroke()
+
+      ctx.restore()
+    }
+  }
 
   // ── result card ───────────────────────────────────────────────────────────
 
