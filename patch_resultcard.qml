--- components/ResultCard.qml
+++ components/ResultCard.qml
@@ -15,6 +15,8 @@
   property string scopeState: "Idle"
   property string responseText: ""
   property var webSources: []
+  property string activityTitle: ""
+  property string activityDetail: ""
   property bool isExpanded: false
   property bool escalationPending: false
 
@@ -139,12 +141,25 @@
       LoadingDots {}
 
-      Text {
-    textFormat: Text.PlainText
-        anchors.verticalCenter: parent.verticalCenter
-        text: "Searching…"
-        color: Color.popups.text
-        opacity: 0.72
-        font.pixelSize: Style.font.body
-        font.family: Style.font.menuFamily
+      Column {
+        anchors.verticalCenter: parent.verticalCenter
+        spacing: Style.spacing.xs
+
+        Text {
+          textFormat: Text.PlainText
+          text: root.activityTitle !== "" ? root.activityTitle : "Searching…"
+          color: Color.popups.text
+          opacity: 0.72
+          font.pixelSize: Style.font.body
+          font.family: Style.font.menuFamily
+        }
+        Text {
+          textFormat: Text.PlainText
+          visible: root.activityDetail !== ""
+          text: root.activityDetail
+          color: Color.popups.text
+          opacity: 0.50
+          font.pixelSize: Style.font.small
+          font.family: Style.font.menuFamily
+          elide: Text.ElideRight
+          width: Math.min(implicitWidth, root.width - (Style.spacing.popupPadding * 2) - Style.spacing.lg - 40)
+        }
       }
     }
