
assert_output_contains "lasso: release sets finalOutlineVisible = true" "panel.finalOutlineVisible = true" \
  rg "panel.finalOutlineVisible = true" "$PLUGIN_DIR/ScopeOverlay.qml"
assert_output_contains "lasso: outline remains visual after pointer release" "panel.finalOutlineVisible" \
  rg "visible: panel.isActiveScreen && panel.finalOutlineVisible" "$PLUGIN_DIR/ScopeOverlay.qml"
assert_output_contains "lasso: timer interval is 3000 ms" "interval: 3000" \
  rg "interval: 3000" "$PLUGIN_DIR/ScopeOverlay.qml"
assert_output_contains "lasso: timeout hides ONLY the visual outline" "panel.finalOutlineVisible = false" \
  rg -A 2 "onTriggered:" "$PLUGIN_DIR/ScopeOverlay.qml"
assert_output_contains "lasso: reset prevents stale outline" "panel.finalOutlineVisible = false" \
  rg "onScopeStateChanged:" "$PLUGIN_DIR/ScopeOverlay.qml"

echo -e "\n§16 Autofocus Optimization"
assert_output_contains "autofocus: initial result triggers follow-up focus" "focusFollowUp" \
  rg -A 3 "onScopeStateChanged:" "$PLUGIN_DIR/components/ResultCard.qml"
assert_output_contains "autofocus: provides focusFollowUp method" "followUp.forceActiveFocus" \
  rg -A 2 "function focusFollowUp" "$PLUGIN_DIR/components/ResultCard.qml"
assert_output_contains "autofocus: Escape still reaches Scope while input has focus" "Qt.Key_Escape" \
  rg -A 3 "Keys.onPressed:" "$PLUGIN_DIR/components/ResultCard.qml"
assert_output_contains "autofocus: empty Enter does not submit" "if (!question) return" \
  rg -A 3 "onAccepted:" "$PLUGIN_DIR/components/ResultCard.qml"
