--- ScopeService.qml
+++ ScopeService.qml
@@ -150,14 +150,22 @@
         if (obj.item.query) {
           q = obj.item.query
         } else if (obj.item.action && obj.item.action.queries && obj.item.action.queries.length > 0) {
           q = obj.item.action.queries[0]
         }
         if (q) {
           q = q.replace(/[\x00-\x1F\x7F]/g, "").trim()
           if (q.length > 250) q = q.substring(0, 250) + "…"
           root.activityEvent("web-search", "Searching the web", q)
         }
+      } else if (obj.type === "item.completed" && obj.item && obj.item.type === "command_execution") {
+        var cmd = obj.item.command || ""
+        if (cmd) {
+          cmd = cmd.replace(/[\x00-\x1F\x7F]/g, "").trim()
+          if (cmd.length > 250) cmd = cmd.substring(0, 250) + "…"
+          root.activityEvent("command", "Analyzing environment", cmd)
+        }
       }
     } catch (e) {}
   }
