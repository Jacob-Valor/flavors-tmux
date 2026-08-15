#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Perf regression harness.
#
# Benchmarks the Rust binary's render latencies (cold + warm) for the widgets
# that matter in the statusline hot path, and exits non-zero if a warm render
# regresses beyond a threshold vs. a recorded baseline.
#
# Usage:
#   bash scripts/perf-harness.sh            # run + compare to baseline
#   bash scripts/perf-harness.sh --update   # (re)record the baseline
#
# Baselines are stored in .perf-baseline.json next to this script.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BIN="${PROJECT_DIR}/target/release/flavors_tmux"
BASELINE_FILE="${SCRIPT_DIR}/.perf-baseline.json"

# Warm renders must not exceed baseline by more than this fraction (e.g. 0.5 = +50%).
# Cold renders are noisy (first run, forge TTL expiry) so they're informational only.
WARM_TOLERANCE=0.5

if [[ ! -x "$BIN" ]]; then
	echo "Building release binary..." >&2
	(cd "$PROJECT_DIR" && cargo build --release) >/dev/null 2>&1 || {
		echo "BUILD FAILED" >&2
		exit 1
	}
fi

# --- Benchmarks ------------------------------------------------------------
# Each benchmark runs the binary N times and reports the mean latency in ms.
# The widget set mirrors what a typical status-right actually enables.

N_WARM=50
N_COLD=5

run_bench() {
	local label="$1" cmd="$2" n="$3"
	local total=0
	for _ in $(seq "$n"); do
		local t0 t1
		t0=$(date +%s%N)
		# shellcheck disable=SC2086
		eval "$cmd" >/dev/null 2>&1
		t1=$(date +%s%N)
		total=$((total + (t1 - t0)))
	done
	# ms with 2 decimals
	awk -v ns="$total" -v n="$n" 'BEGIN { printf "%.2f", ns / n / 1e6 }'
}

# Warm up caches for the widget set
./"$BIN" status --theme hard --pane-path . cwd,git,wb-git,datetime >/dev/null 2>&1 || true

WARM_4WIDGET=$(run_bench "4-widget warm" "./$BIN status --theme hard --pane-path . cwd,git,datetime,battery" "$N_WARM")
WARM_WBGIT=$(run_bench "wb-git warm" "./$BIN status --theme hard --pane-path . wb-git" "$N_WARM")
WARM_MAX=$(run_bench "8-widget warm" "./$BIN status --theme hard --pane-path . cwd,git,wb-git,cpu,datetime,battery,kubernetes,gpg-ssh" "$N_WARM")
COLD_4WIDGET=$(run_bench "4-widget cold" "./$BIN status --theme hard --pane-path . cwd,git,datetime,battery" "$N_COLD")

echo "=== Perf harness (mean per render) ==="
echo "  warm  4-widget : ${WARM_4WIDGET} ms"
echo "  warm  wb-git   : ${WARM_WBGIT} ms"
echo "  warm  8-widget : ${WARM_MAX} ms"
echo "  cold  4-widget : ${COLD_4WIDGET} ms (informational)"

if [[ "${1:-}" == "--update" ]]; then
	cat >"$BASELINE_FILE" <<EOF
{
  "warm_4widget_ms": ${WARM_4WIDGET},
  "warm_wbgit_ms": ${WARM_WBGIT},
  "warm_maxwidget_ms": ${WARM_MAX},
  "cold_4widget_ms": ${COLD_4WIDGET},
  "recorded": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
	echo ""
	echo "Baseline recorded to ${BASELINE_FILE}"
	exit 0
fi

if [[ ! -f "$BASELINE_FILE" ]]; then
	echo ""
	echo "No baseline found. Run: bash scripts/perf-harness.sh --update"
	exit 0
fi

# --- Compare to baseline ---------------------------------------------------
# shellcheck disable=SC1091
BASE_4=$(python3 -c "import json;print(json.load(open('${BASELINE_FILE}'))['warm_4widget_ms'])")
BASE_WB=$(python3 -c "import json;print(json.load(open('${BASELINE_FILE}'))['warm_wbgit_ms'])")
BASE_MAX=$(python3 -c "import json;print(json.load(open('${BASELINE_FILE}'))['warm_maxwidget_ms'])")

fail=0
check_regression() {
	local label="$1" current="$2" baseline="$3"
	local limit
	limit=$(awk -v b="$baseline" -v t="$WARM_TOLERANCE" 'BEGIN { printf "%.2f", b * (1 + t) }')
	if awk -v c="$current" -v l="$limit" 'BEGIN { exit !(c > l) }'; then
		echo "  FAIL: ${label} ${current} ms exceeds ${limit} ms (baseline ${baseline} ms, +${WARM_TOLERANCE})" >&2
		fail=1
	else
		echo "  ok:   ${label} ${current} ms (baseline ${baseline} ms)"
	fi
}

echo ""
echo "=== Baseline comparison (warm, tolerance +${WARM_TOLERANCE}) ==="
check_regression "4-widget" "$WARM_4WIDGET" "$BASE_4"
check_regression "wb-git" "$WARM_WBGIT" "$BASE_WB"
check_regression "max-widget" "$WARM_MAX" "$BASE_MAX"

if [[ $fail -ne 0 ]]; then
	echo ""
	echo "PERF REGRESSION DETECTED — warm renders slower than baseline." >&2
	echo "If the change is intentional, re-record: bash scripts/perf-harness.sh --update" >&2
	exit 1
fi

echo ""
echo "Perf OK: all warm renders within tolerance."
exit 0
