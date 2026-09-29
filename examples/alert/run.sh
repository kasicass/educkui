#!/usr/bin/env bash
# Alert dialog example runner (uses a Ctrl+A shortcut to open the dialog).
set -euo pipefail

cd "$(dirname "$0")/../.."

echo "==> compiling educkui"
rebar3 compile >/dev/null

echo "==> compiling alert example"
mkdir -p /tmp/dui_example
erlc -I include -pa _build/default/lib/educkui/ebin \
    -o /tmp/dui_example examples/alert/dui_alert.erl

echo "==> running (Ctrl+A open dialog, Enter/Space activate, Esc close/quit)"
erl -noshell \
    -pa /tmp/dui_example \
    -pa _build/default/lib/educkui/ebin \
    -eval 'educkui:run([{root, dui_alert},
                        {shortcuts, [{{<<"a">>, [ctrl]}, {msg, toggle_dialog}}]}]).' \
    -eval 'init:stop().'
