--- ScopeService.qml
+++ ScopeService.qml
@@ -343,21 +343,26 @@
     id: analyzeProc
     running: false
 
-    stdout: StdioCollector {
-      waitForEnd: true
-      onStreamFinished: {
+    stdout: SplitParser {
+      splitMarker: "\n"
+      onRead: function(data) {
         if (root.workCancelled) return
-        var path = text.trim()
-        if (!path) return  // Exit handler will report
-        if (path.startsWith("ERROR:")) {
-          root.analysisFailed(path.substring(7).trim() || "Agent analysis failed.")
+        var text = data.trim()
+        if (!text) return
+
+        if (text.startsWith("{")) {
+          root.handleActivityEvent(text)
+          return
+        }
+        if (text.startsWith("ERROR:")) {
+          root.analysisFailed(text.substring(7).trim() || "Agent analysis failed.")
           return
         }
-        if (!path.startsWith(root.runtimeBase + "/")) {
-          root.analysisFailed("Analysis returned invalid path.")
+        if (text.startsWith(root.runtimeBase + "/")) {
+          root.analysisSucceeded(text)
           return
         }
-        root.analysisSucceeded(path)
       }
     }
     stderr: StdioCollector {
