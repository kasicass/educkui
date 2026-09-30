# Components

Components are the user-facing building blocks of an educkui application.
There are two component behaviours:

- `educkui_elm` — stateful components following The Elm Architecture.
- `educkui_component` — stateless widgets with a single `render/2` callback.

## Elm components

A root application (or stateful widget) implements
`-behaviour(educkui_elm).`:

```erlang
-module(dui_counter).
-behaviour(educkui_elm).
-include_lib("educkui/include/educkui.hrl").
-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) -> #{count => 0}.

event_to_msg(#dui_event{type = key, key = up}, _S)   -> {msg, inc};
event_to_msg(#dui_event{type = key, key = down}, _S) -> {msg, dec};
event_to_msg(_, _) -> ignore.

update(inc, S) -> {S#{count := maps:get(count, S) + 1}, []};
update(dec, S) -> {S#{count := maps:get(count, S) - 1}, []}.

view(S) ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(integer_to_binary(maps:get(count, S)))
    ]).
```

`event_to_msg/2` returns one of:

- `{msg, Msg}` — dispatch `Msg` to `update/2`
- `ignore` — consume the event without changing state
- `propagate` — bubble the event to the root component

`update/2` returns:

- `{State, Commands}`
- `{State}` (shorthand for no commands)
- `noreply` (keep the previous state)

## Render nodes

`view/1` returns a render tree made of `#dui_node{}` records. Use the
constructors in `educkui_render_node`:

| Constructor | Description |
|---|---|
| `empty/0` | Nothing |
| `text/1,2` | A text line with an optional style |
| `box/1,2` | A box with background/children and optional style/width/height/align |
| `stack/2,3` | Vertical or horizontal stack of children |
| `cells/1,2` | Explicitly positioned `{X, Y, Cell}` list |
| `overlay/1,2` | Children rendered on top of each other |
| `at/3` | Place a child at absolute `{X, Y}` within the parent |
| `widget/2,3` | Stateless widget node |
| `component/2,3` | Stateful child component node |
| `styled/2` | Wrap a node in a style box |
| `width/2`, `height/2` | Override a node's natural size |

Example:

```erlang
educkui_render_node:stack(vertical, [
    educkui_render_node:text(<<"Hello">>, educkui_style:from([{bold, true}])),
    educkui_render_node:box([educkui_render_node:text(<<"inside">>)],
                            [{style, educkui_style:from([{bg, blue}])}])
]).
```

## Stateless widgets

A stateless widget implements `educkui_component`:

```erlang
-behaviour(educkui_component).
-export([render/2, describe/0, default_props/0]).

render(Props, Rect) -> educkui_render_node:text(maps:get(text, Props, <<>>)).
describe() -> #{name => <<"Label">>, description => <<"...">>}.
default_props() -> #{text => <<>>}.
```

Stateless widgets are embedded with `widget/2,3`; the renderer calls
`Module:render(Props, Rect)`.

## Child components

Stateful Elm widgets are embedded with `component/2,3`. The runtime keeps
their state in a component table keyed by `Id`:

```erlang
educkui_render_node:component(name_input, educkui_widget_text_input,
                              #{value => <<"Alice">>}).
```

On each render, the runtime ensures the component is initialized (calling
`init/1` with the props list), calls its `view/1`, and rasterizes the result
inside the component's rect. Events are dispatched to the focused component,
whose `event_to_msg/2` and `update/2` run in the runtime process.

## Commands

Commands are plain terms returned by `update/2`:

| Command | Meaning |
|---|---|
| `{quit}` | Stop the runtime |
| `{noop}` | Do nothing |
| `{send, Pid, Msg}` | Send a message to a process |
| `{exec, Fun}` | Run `Fun/0` asynchronously and deliver the result as a `command_result` event |
| `{focus, Id}` | Move focus to component `Id` |
| `{parent, Msg}` | Send `Msg` to the root component as a `parent` event |

`educkui_command` provides constructors: `quit/0`, `noop/0`, `send_msg/2`,
`exec/1`, `focus/1`, `parent/1`.

## Props validation

`educkui_component_helpers:props/2` extracts typed props with defaults:

```erlang
Props = educkui_component_helpers:props(Raw, [
    {text, string, [{default, <<>>}]},
    {align, atom, [{default, left}]}
]).
```

## Focus

Focus is a stack of component ids. Tab/Shift+Tab move focus through the
components discovered during rendering; mouse clicks move focus by hit
testing. Components are notified through `focus(gained)` and `focus(lost)`
events.

When there are no focusable components, Tab is delivered to the root so it
can implement its own field navigation (e.g. a form). Pass
`focusable => false` in a component's props to keep a transparent overlay
(such as a mouse-capturing layer) out of Tab traversal.

## Runtime control

- `educkui:run(Opts)` — start the runtime and block until it exits.
- `educkui:start(Opts)` — start without blocking.
- `educkui_runtime:send_event(Runtime, Event)` — inject an event.
- `educkui_runtime:send_message(Runtime, ComponentId, Message)` — send a
  directed message to a component.
- `educkui_runtime:force_render(Runtime)` — force an immediate render.
- `educkui_runtime:size(Runtime)` — current `{Rows, Cols}`.
- `educkui_runtime:copy_to_clipboard(Text)` — OSC 52 clipboard copy (no-op on
  the `skip` backend).
- `educkui_runtime:logs(Runtime)` / `clear_logs(Runtime)` — buffered log events
  (see "Logs" below).

## Asynchronous commands

`update/2` may return `{exec, Fun}` commands. `Fun/0` runs in a separate
process and its result is delivered back to the component that returned it as
`#dui_event{type = custom, key = command_result, content = {Id, Result}}`:

```erlang
event_to_msg(#dui_event{type = custom, key = command_result,
                        content = {_Id, Result}}, State) ->
    {msg, {result, Result}}.
```

## Timers and intervals

Use `educkui_command:interval/2,3` for periodic work (TTL countdowns, metrics
refresh, watch mode). The runtime schedules it with `erlang:send_after/3` and
delivers the message to the root component as a `parent` event:

```erlang
update(start_clock, State) ->
    {State, [educkui_command:interval(tick, 1000)]};
update(tick, State) ->
    {State#{now := erlang:system_time(second)}, []}.

event_to_msg(#dui_event{type = custom, key = parent, content = Msg}, _State) ->
    {msg, Msg}.
```

`interval/3` lets you supply the timer reference so it can be cancelled with
`educkui_command:cancel_interval/1`. All pending timers are cancelled when the
runtime stops.

## Controlled components and state access

By default a child component's state is private and its props are only read
once at init. To drive a component from its parent, mount it and push props
explicitly:

```erlang
%% parent update/2
educkui_runtime:set_props(Runtime, name_input, #{value => <<"Bob">>}),
```

If the component implements the optional `handle_props/2` callback it will
adopt the new props; `educkui_widget_text_input` and
`educkui_widget_text_area` do. Read back state with
`educkui_runtime:get_component_state(Runtime, Id)`.

For reusable single-line editing logic, use the pure `educkui_lineedit`
module (`new/1`, `insert/2`, `backspace/1`, `delete/1`, `move/2`, `home/1`,
`'end'/1`).

## Logs

While the alternate screen is active the runtime installs
`educkui_log_handler`, which buffers `logger` events in `educkui_log` instead of
writing them to the terminal (terminal handlers are silenced for the duration).
Applications can render them, e.g. on a Logs screen:

```erlang
Lines = [format_log(E) || E <- educkui_runtime:logs(Runtime)].
```

## Clipboard

`educkui_runtime:copy_to_clipboard/1` emits an OSC 52 sequence to copy text to
the system clipboard. Terminals that do not support OSC 52 silently ignore it;
an application may fall back to `pbcopy`/`xclip`/`wl-copy` if needed.

## Testing

`educkui_test` starts a headless runtime (the `skip` backend) and drives it:

```erlang
Pid = educkui_test:start(#{root => my_app, size => {24, 80}}),
ok = educkui_test:send_key(Pid, down),
ok = educkui_test:assert_text(Pid, <<"Selected">>),
ok = educkui_test:set_props(Pid, name_input, #{value => <<"x">>}),
{ok, State} = educkui_test:get_component_state(Pid, name_input),
ok = educkui_test:stop(Pid).
```

`wait_until/2,3` polls the root state until a predicate holds, which is handy
for asynchronous `{exec, ...}` results.
