#!/usr/bin/env bash
# Builds and runs the dashboard showcase example.
set -euo pipefail

cd "$(dirname "$0")/../.."

echo "==> compiling educkui"
rebar3 compile >/dev/null

echo "==> compiling dashboard example"
mkdir -p /tmp/dui_dashboard_example
erlc -I include -pa _build/default/lib/educkui/ebin \
    -o /tmp/dui_dashboard_example examples/dashboard/dui_dashboard.erl

echo "==> running (Ctrl+D dialog, Esc quit)"
erl -noshell \
    -pa /tmp/dui_dashboard_example \
    -pa _build/default/lib/educkui/ebin \
    -eval 'educkui:run([{root, dui_dashboard},
                        {shortcuts, [{{<<"d">>, [ctrl]}, {msg, toggle_dialog}}]}]).' \
    -eval 'init:stop().'
