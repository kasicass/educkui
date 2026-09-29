%% @doc Pick list showcase with type-ahead filtering.
-module(dui_picklist).

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
            <<"Pick list - Tab to focus, type to filter, Up/Down select, Enter commit, Esc quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"">>),
        educkui_render_node:component(pick, educkui_widget_pick_list, #{
            items => [<<"apple">>, <<"banana">>, <<"cherry">>, <<"durian">>,
                      <<"elderberry">>, <<"fig">>, <<"grape">>],
            prompt => <<"Fruit: ">>
        })
    ]).
