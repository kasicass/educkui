#!/usr/bin/env bash
# Generic example runner: ./run_example.sh <module_name>
# Builds educkui, compiles examples/<module_name>/dui_<module_name>.erl and
# runs it with `educkui:run([{root, dui_<module_name>}]).`
set -euo pipefail

MODULE="$1"
cd "$(dirname "$0")/.."

echo "==> compiling educkui"
rebar3 compile >/dev/null

echo "==> compiling example ${MODULE}"
mkdir -p /tmp/dui_example
erlc -I include -pa _build/default/lib/educkui/ebin \
    -o /tmp/dui_example "examples/${MODULE}/dui_${MODULE}.erl"

echo "==> running (Esc to quit)"
erl -noshell \
    -pa /tmp/dui_example \
    -pa _build/default/lib/educkui/ebin \
    -eval "educkui:run([{root, dui_${MODULE}}])." \
    -eval 'init:stop().'
