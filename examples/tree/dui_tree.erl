%% @doc Tree view showcase: expand/collapse and selection navigation.
-module(dui_tree).

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
        educkui_render_node:text(
            <<"Tree view - Tab to focus, Up/Down select, Right/Left expand/collapse, Esc quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"">>),
        educkui_render_node:component(tree, educkui_widget_tree_view, #{
            items => [
                {src, <<"src">>, [
                    {widgets, <<"widgets">>, [
                        {label, <<"educkui_widget_label.erl">>, []},
                        {dialog, <<"educkui_widget_dialog.erl">>, []}
                    ]},
                    {core, <<"educkui_runtime.erl">>, []}
                ]},
                {test, <<"test">>, [
                    {eunit, <<"educkui_runtime_tests.erl">>, []}
                ]},
                {readme, <<"README.md">>, []}
            ]
        })
    ]).
