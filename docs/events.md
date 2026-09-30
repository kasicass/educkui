# Events

Events are represented by the `#dui_event{}` record defined in
`include/educkui.hrl`:

```erlang
-record(dui_event, {
    type,                 %% key | mouse | focus | resize | paste | tick | custom
    key,                  %% atom | binary()
    char,                 %% binary() | undefined
    modifiers = [],       %% ordset of ctrl | shift | alt | meta
    action,               %% mouse/focus action
    button,               %% left | middle | right | undefined
    x, y,                 %% mouse coordinates
    width, height,        %% resize dimensions
    interval,             %% tick interval
    content,              %% paste content / custom payload
    timestamp = 0
}).
```

Constructors live in `educkui_event`:

```erlang
educkui_event:key(up),
educkui_event:key(<<"q">>, [{char, <<"q">>}]),
educkui_event:mouse(press, left, X, Y),
educkui_event:focus(gained),
educkui_event:resize(Cols, Rows),
educkui_event:paste(<<"text">>),
educkui_event:tick(1000),
educkui_event:custom(command_result, {ComponentId, Result}).
```

## Key events

`educkui_escape_parser` converts terminal bytes into key events:

- Printable ASCII and UTF-8 characters: `key` and `char` are both the
  grapheme binary.
- Control characters: `backspace`, `tab`, `enter`, `esc`.
- Ctrl+letter: `key` is the letter binary and `modifiers` contains `ctrl`.
- CSI/SS3 sequences: arrows (`up`, `down`, `left`, `right`), `home`, `end`,
  `insert`, `delete`, `page_up`, `page_down`, `f1`..`f12`.
- Modified keys carry `ctrl`, `shift`, `alt` and/or `meta` in `modifiers`.

## Mouse events

SGR mouse tracking reports press/release/drag/scroll events. `action` is
`press`, `release` or `scroll`; `button` is `left`, `middle` or `right`;
`x` and `y` are terminal coordinates (clamped to 9999).

Mouse presses are hit-tested against the component target rectangles built
during rendering. When a component is clicked, the runtime translates the
coordinates to component-local space before dispatching.

## Paste events

Bracketed paste (`ESC[200~ ... ESC[201~`) produces a `paste` event with the
clipboard text in `content`.

## Resize events

A terminal resize (SIGWINCH) is forwarded by `educkui_signal_handler` and
re-detected through `educkui_terminal_size`. The runtime then applies the new
dimensions to both buffers and marks the frame dirty.

## Focus events

When focus moves (Tab/Shift+Tab or a mouse click), the runtime sends
`focus(lost)` to the previously focused component and `focus(gained)` to the
newly focused component.

## Custom events

Components and the runtime use custom events internally:

- `{parent, Msg}` commands become a custom event with `key = parent` sent to
  the root component.
- `educkui_runtime:send_message/3` becomes a custom event with
  `key = message` and `content = {ComponentId, Message}`, routed to that
  component.
- Command results become `key = command_result` with
  `content = {ComponentId, Result}`.

## Routing

`educkui_event_router:route/3` routes:

- key and paste events to the focused component,
- mouse events by hit-testing target rectangles,
- directed `message` custom events to the addressed component.

Unhandled events can return `propagate` from `event_to_msg/2` to bubble the
same event up to the root component.
