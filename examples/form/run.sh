#!/usr/bin/env bash
# Builds and runs the form example.
set -euo pipefail

cd "$(dirname "$0")/../.."

echo "==> compiling educkui"
rebar3 compile >/dev/null

echo "==> compiling form example"
mkdir -p /tmp/dui_form_example
erlc -I include -pa _build/default/lib/educkui/ebin \
    -o /tmp/dui_form_example examples/form/dui_form.erl

echo "==> running (Tab to switch, type to edit, Esc to quit)"
erl -noshell \
    -pa /tmp/dui_form_example \
    -pa _build/default/lib/educkui/ebin \
    -eval 'educkui:run([{root, dui_form}]).' \
    -eval 'init:stop().'
