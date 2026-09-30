# Architecture

educkui is a pure-Erlang terminal UI framework built on OTP 28. It follows
The Elm Architecture: terminal input is parsed into events, events are
converted to messages, messages update application state, and the state is
rendered into a terminal buffer each tick.

## Data flow

```
terminal input
      │
      ▼
escape parser ──► event ──► event router ──► event_to_msg ──► update
                                                              │
                                              (new state, commands)
                                                              │
                                                    command executor
                                                              │
render tick ──► view ──► render node ──► renderer ──► buffer (current)
                                                              │
                                     diff / changed cells      │
                                                              ▼
                                                        backend ──► terminal
```

## Layers

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

## Runtime loop

`educkui_runtime` is a `gen_server` that owns the application state and
orchestrates both the event loop and the render loop:

1. `init/1` selects a backend (`raw` first, falling back to `tty`),
   starts the command executor and input reader, initializes the root
   component, and schedules the first render tick.
2. Input bytes arrive asynchronously from the reader process and are fed to
   `educkui_escape_parser`. Parsed events are routed and dispatched.
3. Each `update/2` returns `{State, Commands}`. Commands are either handled
   directly by the runtime (`{focus, Id}`, `{parent, Msg}`) or executed
   asynchronously by `educkui_command_executor`.
4. A render tick fires every `render_interval` ms (default 16). When the
   state is dirty, `view/1` produces a render tree that is rasterized into
   the current buffer.
5. Only cells that differ from the previous frame are emitted to the
   backend, using cursor-movement optimization and style deltas.

## Screen buffer and diffing

- The screen buffer is an ETS `ordered_set` keyed by `{Row, Col}`.
- Two buffers are kept: `current` and `previous`. After each render they are
  swapped.
- `educkui_diff` compares the two buffers row by row, groups changed cells
  into spans, merges nearby spans, and splits them by style.
- `educkui_sequence_buffer` turns the diff operations into an iolist, and
  `educkui_cursor_optimizer` chooses relative versus absolute cursor moves.

## Backends

- `raw` uses `shell:start_interactive({noshell, raw})` (OTP 26+) plus the
  alternate screen, bracketed paste, mouse tracking and focus reporting.
- `tty` is a line-buffered fallback for remote or restricted environments.
- `educkui_backend_selector` tries `raw` first and falls back to `tty`.
- `skip` is used by tests to run the runtime without touching the terminal.

## Terminal capabilities and degradation

`educkui_capabilities` detects color depth (`true_color`, `color_256`,
`color_16`, `monochrome`), Unicode support and TTY-ness. Rendering and
widgets degrade gracefully: colors are reduced and box/block characters fall
back to ASCII via `educkui_character_set`.
