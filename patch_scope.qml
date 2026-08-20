--- Scope.qml
+++ Scope.qml
@@ -62,6 +62,8 @@
   property string errorText: ""
   property var webSources: []
   property string pendingQuestion: ""
+  property string activityTitle: ""
+  property string activityDetail: ""
   property string latestFollowUp: ""
   property int responseGeneration: -1
   property bool escalationPending: false
@@ -193,6 +195,8 @@
     root.errorText = ""
     root.responseText = ""
     root.webSources = []
+    root.activityTitle = ""
+    root.activityDetail = ""
     root.pendingQuestion = ""
     root.latestFollowUp = ""
     root.escalationPending = false
@@ -242,6 +246,8 @@
 
     onInvocationIdReady: function(id) { root.invocationId = id }
 
+    onActivityEvent: function(type, title, detail) {
+      root.activityTitle = title
+      root.activityDetail = detail
+    }
+
     onAnalysisSucceeded: function(responsePath) {
       // Guard against stale callbacks.
       if (root.state !== "Searching") return
