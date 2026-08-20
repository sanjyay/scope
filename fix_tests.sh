sed -i '/echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"/,$d' tests/run-tests.sh
cat patch_tests_activity.sh >> tests/run-tests.sh
cat << 'TAIL' >> tests/run-tests.sh

echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo ""

if (( FAIL > 0 )); then
  echo "Some tests FAILED. Review output above."
  exit 1
else
  echo "All tests passed."
  exit 0
fi
TAIL
