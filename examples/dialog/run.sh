#!/usr/bin/env bash
# Dialog example runner (uses a Ctrl+D shortcut to open the dialog).
set -euo pipefail

cd "$(dirname "$0")/../.."

echo "==> compiling educkui"
rebar3 compile >/dev/null

echo "==> compiling dialog example"
mkdir -p /tmp/dui_example
erlc -I include -pa _build/default/lib/educkui/ebin \
    -o /tmp/dui_example examples/dialog/dui_dialog.erl

echo "==> running (Ctrl+D open dialog, Enter/Space activate, Esc close/quit)"
erl -noshell \
    -pa /tmp/dui_example \
    -pa _build/default/lib/educkui/ebin \
    -eval 'educkui:run([{root, dui_dialog},
                        {shortcuts, [{{<<"d">>, [ctrl]}, {msg, toggle_dialog}}]}]).' \
    -eval 'init:stop().'
