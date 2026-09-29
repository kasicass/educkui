%% @doc Counter example component used by runtime tests.
-module(dui_counter).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) ->
    #{count => 0}.

event_to_msg(#dui_event{type = key, key = up}, _State) -> {msg, inc};
event_to_msg(#dui_event{type = key, key = down}, _State) -> {msg, dec};
event_to_msg(#dui_event{type = key, key = <<"q">>}, _State) -> {msg, quit};
event_to_msg(#dui_event{type = custom, key = command_result,
                        content = {_Cid, Result}}, State) ->
    {msg, {command_result, Result, maps:get(count, State)}};
event_to_msg(_Event, _State) -> ignore.

update(inc, State) ->
    {State#{count := maps:get(count, State) + 1}, []};
update(dec, State) ->
    {State#{count := maps:get(count, State) - 1}, []};
update(quit, State) ->
    {State, [educkui_command:quit()]};
update({command_result, _Result, _Count}, State) ->
    {State, []}.

view(State) ->
    Count = maps:get(count, State),
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(<<"Counter: ", (integer_to_binary(Count))/binary>>),
        educkui_render_node:text(<<"up/down to change, q to quit">>)
    ]).
