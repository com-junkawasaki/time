#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# mathlib の prebuilt olean を先に取得（cold cache でソースビルドすると数時間
# かかるため。オフライン等で失敗しても手元の .lake で続行する）
lake exe cache get || echo "warning: lake exe cache get failed (offline?); building with local cache" >&2

lake build

# 未証明マーカー検査。grep 常設コマンドを使う（rg 不在の exit 127 で検査が
# 黙って skip されるのを防ぐ）。rc=0: マーカー発見 → fail / rc=1: 無し → pass /
# rc>=2: 検査自体の失敗 → fail（fail-open にしない）。
# パターンは sorry / sorryAx / admit / native_decide と、修飾子付き・インデント
# された axiom（namespace 内の "  axiom" や "private axiom"）も捕まえる。
set +e
grep -RInE '(^|[^A-Za-z0-9_])(sorry|sorryAx|admit|native_decide)($|[^A-Za-z0-9_])|^[[:space:]]*(private[[:space:]]+|protected[[:space:]]+|noncomputable[[:space:]]+)*axiom([^A-Za-z0-9_]|$)' \
  --include='*.lean' RelationalTime RelationalTime.lean Main.lean
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  echo "unproved declaration marker found" >&2
  exit 1
elif [ "$rc" -ne 1 ]; then
  echo "marker scan failed (grep rc=$rc)" >&2
  exit 1
fi

output="$(lake exe time)"
printf '%s\n' "$output"
grep -q '^RELATIONAL_TIME_PASS$' <<<"$output"
echo "TIME_VERIFY_PASS"
