#!/usr/bin/env bash
# educkui CI: compile -> eunit -> common_test -> dialyzer -> xref.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> compile"
rebar3 compile

echo "==> eunit"
rebar3 eunit

echo "==> common_test"
rebar3 ct

echo "==> xref"
rebar3 xref

echo "==> dialyzer"
rebar3 dialyzer

echo "==> done"
