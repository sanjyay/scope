
echo -e "\n§17 Activity Streaming"
assert_output_contains "activity: JSONL parser uses Quickshell SplitParser" "SplitParser" \
  rg -A 5 "stdout: SplitParser" "$PLUGIN_DIR/ScopeService.qml"
assert_output_contains "activity: malformed event ignored safely" "try {" \
  rg -A 5 "handleActivityEvent" "$PLUGIN_DIR/ScopeService.qml"
assert_output_contains "activity: unknown event ignored" "if (obj.item.type ===" \
  rg -A 10 "handleActivityEvent" "$PLUGIN_DIR/ScopeService.qml"
assert_output_contains "activity: null fields guarded" "&& obj.item" \
  rg "&& obj.item" "$PLUGIN_DIR/ScopeService.qml"
assert_output_contains "activity: oversized event truncated" "substring(0, 250)" \
  rg "substring(0, 250)" "$PLUGIN_DIR/ScopeService.qml"
assert_output_contains "activity: stale session event ignored" "service.activeGeneration !== root.sessionGeneration" \
  rg -A 2 "function onActivityEvent" "$PLUGIN_DIR/Scope.qml"
assert_output_contains "activity: cancellation ignores trailing chunks" "if (root.workCancelled) return" \
  rg -A 5 "SplitParser" "$PLUGIN_DIR/ScopeService.qml"
assert_output_contains "activity: plain text only" "textFormat: Text.PlainText" \
  rg -A 3 "text: root.activityTitle" "$PLUGIN_DIR/components/ResultCard.qml"
