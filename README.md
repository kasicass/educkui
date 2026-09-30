# educkui

A pure-Erlang terminal UI (TUI) framework for OTP 28+, inspired by
[term_ui](https://github.com/pcharbon70/term_ui) / BubbleTea / Ratatui.

`educkui` builds on the BEAM's strengths — supervision trees, behaviours, actor
concurrency — to write robust terminal applications using
[The Elm Architecture](https://guide.elm-lang.org/architecture/).

- **No NIFs, no port drivers, no external dependencies** — raw mode uses
  `shell:start_interactive({noshell, raw})` (OTP 26+).
- **Pure Erlang**, rebar3 build, EUnit tests, Dialyzer + xref clean.

## Features

- The Elm Architecture (`init/1`, `event_to_msg/2`, `update/2`, `view/1`)
- Double-buffered, differential rendering with an ETS-backed screen buffer
- Raw and TTY backends with automatic selection and graceful degradation
- Full keyboard/mouse/paste/resize input parsing
- True color (RGB), 256-color, 16-color and named-color styles
- Grapheme-cluster-aware text, wide-character and display-width handling
- Layout constraints/solver, themes, Unicode/ASCII character-set fallback
- Component tree with focus management (Tab/Shift+Tab, mouse click) and
  event bubbling
- Widget library: label, block, button, progress, list, text input, text
  area, text view, pick list, scrollable list, table, tabs, split pane, tree
  view, viewport, scroll bar, dialog, alert dialog, toast, context menu, gauge,
  line chart, sparkline, bar chart, canvas, spinner, process monitor,
  supervision tree viewer, log viewer, form builder, stream
- Async command results, `interval`/`cancel_interval` timers, terminal size
  delivery, controlled components (`set_props`/`get_component_state`)
- Pure `educkui_lineedit`, OSC 52 clipboard, bounded `educkui_log`, and the
  `educkui_test` headless harness

## Requirements

- Erlang/OTP 28+
- rebar3

## Quick start

A counter application:

```erlang
-module(dui_counter).
-behaviour(educkui_elm).
-include_lib("educkui/include/educkui.hrl").
-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) -> #{count => 0}.

event_to_msg(#dui_event{type = key, key = up}, _S) -> {msg, inc};
event_to_msg(#dui_event{type = key, key = down}, _S) -> {msg, dec};
event_to_msg(#dui_event{type = key, key = <<"q">>}, _S) -> {msg, quit};
event_to_msg(_, _) -> ignore.

update(inc, S) -> {S#{count := maps:get(count, S) + 1}, []};
update(dec, S) -> {S#{count := maps:get(count, S) - 1}, []};
update(quit, S) -> {S, [educkui_command:quit()]}.

view(S) ->
    Count = maps:get(count, S),
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(<<"Counter: ", (integer_to_binary(Count))/binary>>),
        educkui_render_node:text(<<"up/down to change, q to quit">>)
    ]).
```

Run it:

```erlang
educkui:run([{root, dui_counter}]).
```

See `examples/` for runnable demos:

| Example | Widgets |
|---|---|
| `counter` | minimal Elm counter |
| `form` | text input, focus, editing, mouse |
| `dashboard` | tabs, split pane, tree, charts, process monitor, dialog |
| `charts` | gauge, sparkline, line chart, bar chart |
| `table` | table |
| `tree` | tree view |
| `editor` | multi-line text area |
| `picklist` | pick list with type-ahead filtering |
| `ide` | split pane + tree + editor |
| `dialog` | dialog, toast, context menu |
| `form_builder` | text/password/checkbox/radio/select/multi-select form |
| `stream` | bounded streaming buffer with live stats |

Run any of them with `./examples/<name>/run.sh`.

## Architecture

```
input → escape parser → event → event router → event_to_msg → update
  → (state, commands) → command executor
                        ↓
render tick → view → render node → renderer → buffer (current)
  → diff/changed cells → backend → terminal
```

| Layer | Modules |
|---|---|
| Terminal foundation | `educkui_ansi`, `educkui_sgr`, `educkui_style`, `educkui_cell`, `educkui_display_width` |
| Rendering | `educkui_buffer`, `educkui_diff`, `educkui_sequence_buffer`, `educkui_cursor_optimizer`, `educkui_framerate_limiter`, `educkui_render` |
| Backends | `educkui_backend`, `educkui_backend_raw`, `educkui_backend_tty`, `educkui_backend_selector` |
| Terminal | `educkui_terminal`, `educkui_terminal_size`, `educkui_capabilities`, `educkui_term_utils` |
| Input/events | `educkui_escape_parser`, `educkui_input_raw`, `educkui_input_tty`, `educkui_event`, `educkui_event_router`, `educkui_focus`, `educkui_mouse` |
| Components | `educkui_component`, `educkui_render_node`, `educkui_component_helpers`, `educkui_elm`, `educkui_command`, `educkui_command_executor` |
| Runtime | `educkui_runtime`, `educkui_config` |
| Layout/style | `educkui_layout_constraint`, `educkui_layout_solver`, `educkui_layout_cache`, `educkui_theme`, `educkui_character_set` |
| Widgets | `educkui_widget_*` under `src/widgets/` |

## Events

`educkui_escape_parser` parses terminal bytes into `#dui_event{}` records:

- Key events: arrows, function keys, Home/End/PgUp/PgDn, Insert/Delete,
  Ctrl/Alt/Shift modifiers, printable characters, UTF-8
- Mouse events: SGR mouse tracking (press/release/drag/scroll)
- Paste events (bracketed paste), resize events, custom events, tick events

## Rendering

- Components return `#dui_node{}` render trees (`text/box/stack/cells/empty`).
- `educkui_render` rasterizes the tree into positioned cells.
- Cells are written to the current ETS-backed buffer; only changed cells are
  sent to the backend (double buffering).
- The raw backend emits style deltas and optimized cursor movement.

## Testing

```bash
rebar3 compile
rebar3 eunit
rebar3 ct
rebar3 xref
rebar3 dialyzer
rebar3 edoc
```

Or run the full pipeline:

```bash
./scripts/ci.sh
```

## CI and publishing

GitHub Actions runs `./scripts/ci.sh` on every push and pull request
(`.github/workflows/ci.yml`).

To publish to [hex.pm](https://hex.pm):

```bash
# bump vsn in src/educkui.app.src, then tag and push
rebar3 as publish hex publish
```

A tag push (`v*`) also triggers `.github/workflows/publish.yml`, which
publishes using the `HEX_API_KEY` GitHub secret.

## Documentation

See `docs/` for the user guide:

- [architecture](docs/architecture.md)
- [events](docs/events.md)
- [components](docs/components.md)
- [widgets](docs/widgets.md)
- [styling and layout](docs/styling-layout.md)

Generated API docs are produced by `rebar3 edoc`.

## License

Apache-2.0
