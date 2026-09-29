%% @doc Table showcase with a header row.
-module(dui_table).

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
        educkui_render_node:text(<<"Table - Esc to quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"">>),
        educkui_render_node:widget(educkui_widget_table, #{
            header => [<<"Name">>, <<"Role">>, <<"Location">>],
            rows => [
                [<<"Alice">>, <<"Engineer">>, <<"Stockholm">>],
                [<<"Bob">>, <<"Designer">>, <<"London">>],
                [<<"Carol">>, <<"Manager">>, <<"Berlin">>],
                [<<"Dan">>, <<"Intern">>, <<"Paris">>]
            ],
            header_style => #{bold => true}
        })
    ]).
