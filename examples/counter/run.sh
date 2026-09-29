#!/usr/bin/env bash
# Builds and runs the counter example.
set -euo pipefail

cd "$(dirname "$0")/../.."

echo "==> compiling educkui"
rebar3 compile >/dev/null

echo "==> compiling counter example"
mkdir -p /tmp/dui_counter_example
erlc -I include -pa _build/default/lib/educkui/ebin \
    -o /tmp/dui_counter_example examples/counter/dui_counter.erl

echo "==> running (press Up/Down to change the counter, Q to quit)"
erl -noshell \
    -pa /tmp/dui_counter_example \
    -pa _build/default/lib/educkui/ebin \
    -eval 'educkui:run([{root, dui_counter}]).' \
    -eval 'init:stop().'
