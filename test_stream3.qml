import QtQuick 2.15
import Quickshell
import Quickshell.Io

ShellWindow {
  width: 200; height: 200; visible: true
  Process {
    id: proc
    command: ["bash", "-c", "echo 'Line 1'; sleep 1; echo 'Line 2'; sleep 1; echo '/tmp/done'"]
    running: true
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        console.log("Read line: " + data)
        if (data.startsWith("/tmp/done")) Qt.quit()
      }
    }
  }
}
