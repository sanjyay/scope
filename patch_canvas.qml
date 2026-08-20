--- components/LassoOverlay.qml
+++ components/LassoOverlay.qml
@@ -160,7 +160,7 @@
   Canvas {
     id: lassoCanvas
     anchors.fill: parent
-    visible: root.drawing || root.hasSelection
+    visible: root.drawing || root.finalOutlineVisible
     antialiasing: true
 
     onPaint: {
@@ -183,23 +183,16 @@
         }
-        if (close) ctx.closePath()
+        if (close) {
+          // Manually draw line back to start instead of closePath to keep round joins clean
+          ctx.lineTo(pts[0].x, pts[0].y)
+        }
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
       drawPath(!root.drawing)
       ctx.strokeStyle = Color.imagePicker.unselectedBorder
       ctx.lineWidth = Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.20))
       ctx.lineJoin = "round"
       ctx.lineCap = "round"
       ctx.stroke()
 
       // ── main stroke ────────────────────────────────────────────────────
