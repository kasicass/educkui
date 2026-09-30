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

## Runtime control

- `educkui:run(Opts)` — start the runtime and block until it exits.
- `educkui:start(Opts)` — start without blocking.
- `educkui_runtime:send_event(Runtime, Event)` — inject an event.
- `educkui_runtime:send_message(Runtime, ComponentId, Message)` — send a
  directed message to a component.
- `educkui_runtime:force_render(Runtime)` — force an immediate render.
