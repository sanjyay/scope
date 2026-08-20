import QtQuick 2.15
import Quickshell 1.0

ShellWindow {
  width: 200; height: 200; visible: true
  Process {
    id: proc
    command: ["bash", "-c", "echo A; sleep 1; echo B; sleep 1; echo C"]
    running: true
    stdout: StdioCollector {
      waitForEnd: false
      onDataChanged: console.log("onDataChanged", data)
      onTextChanged: console.log("onTextChanged", text)
      // what else?
    }
  }
}
