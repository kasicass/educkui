%% @doc IDE-style layout: split pane with a tree view and a text editor.
-module(dui_ide).

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
            <<"IDE layout - Tab to focus panes, arrows navigate, Esc quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:component(panes, educkui_widget_split_pane, #{
            direction => vertical,
            split => 10,
            children => [tree_pane(), editor_pane()]
        })
    ]).

tree_pane() ->
    educkui_render_node:component(tree, educkui_widget_tree_view, #{
        items => [
            {app, <<"app">>, [
                {models, <<"models">>, []},
                {views, <<"views">>, []}
            ]},
            {config, <<"config">>, []},
            {mix, <<"mix.exs">>, []}
        ]
    }).

editor_pane() ->
    educkui_render_node:component(editor, educkui_widget_text_area, #{
        value => <<"defmodule App do\n  def hello do\n    :world\n  end\nend\n">>}).
