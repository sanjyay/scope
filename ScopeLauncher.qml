import QtQuick
import QtQuick.Effects
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
    tooltipText: "Search screen with Scope"

    iconComponent: Component {
      Item {
        anchors.fill: parent
        Image {
          id: img
          anchors.fill: parent
          source: Qt.resolvedUrl("assets/scope.svg")
          fillMode: Image.PreserveAspectFit
          visible: false
        }
        MultiEffect {
          anchors.fill: img
          source: img
          colorization: 1.0
          colorizationColor: button.active && button.useActiveColor ? button.activeColor : button.foreground
        }
      }
    }

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.openScope()
    }
  }
}
