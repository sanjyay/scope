import QtQuick
import qs.Ui

// Small, stateless launcher for the Scope overlay. The overlay remains the
// single owner of selection and search state; this widget only summons it.
BarWidget {
  id: root
  moduleName: "goblin.scope"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function openScope() {
    if (root.bar && root.bar.shell && typeof root.bar.shell.summon === "function")
      root.bar.shell.summon(root.moduleName, "{}")
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍉"
    tooltipText: "Search screen with Scope"

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.openScope()
    }
  }
}
