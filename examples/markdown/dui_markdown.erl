%% @doc Markdown viewer showcase.
-module(dui_markdown).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) -> #{}.

event_to_msg(#dui_event{type = key, key = esc}, _State) -> {msg, quit};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) -> {State, [educkui_command:quit()]};
update(_Msg, State) -> {State, []}.

view(_State) ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(<<"Markdown - Esc to quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"">>),
        educkui_render_node:widget(educkui_widget_markdown_viewer, #{
            text => doc()
        })
    ]).

doc() ->
    <<"# educkui\n"
      "A **pure Erlang** terminal UI framework.\n"
      "\n"
      "## Features\n"
      "- The Elm Architecture\n"
      "- *Double-buffered* differential rendering\n"
      "- Raw and TTY backends\n"
      "- Rich widget library\n"
      "\n"
      "## Quick start\n"
      "Run a counter with `educkui:run([{root, dui_counter}])`.\n">>.
