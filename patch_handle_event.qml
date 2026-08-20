--- ScopeService.qml
+++ ScopeService.qml
@@ -142,6 +142,28 @@
     if (analyzeProc.running) analyzeProc.running = false
   }
 
+  function handleActivityEvent(jsonString) {
+    try {
+      var obj = JSON.parse(jsonString)
+      if (obj.type === "turn.started") {
+        root.activityEvent("status", "Analyzing selection…", "")
+      } else if (obj.type === "item.completed" && obj.item && obj.item.type === "web_search") {
+        var q = ""
+        if (obj.item.query) {
+          q = obj.item.query
+        } else if (obj.item.action && obj.item.action.queries && obj.item.action.queries.length > 0) {
+          q = obj.item.action.queries[0]
+        }
+        if (q) {
+          // Simple sanitization: remove control chars
+          q = q.replace(/[\x00-\x1F\x7F]/g, "").trim()
+          if (q.length > 250) q = q.substring(0, 250) + "…"
+          root.activityEvent("web-search", "Searching the web", q)
+        }
+      }
+    } catch (e) {}
+  }
+
   function cleanupInvocation(invId) {
     if (!invId || !/^[0-9a-f]{16}$/.test(invId)) return
