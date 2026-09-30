%% @doc Probe component used by runtime tests for async commands, interval
%% timers and resize delivery.
-module(dui_probe).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

-spec init([{atom(), term()}]) -> map().
init(_Opts) ->
    #{result => undefined,
      ticks => 0,
      timer => undefined,
      size => undefined,
      last_key => undefined}.

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = run}, _State) -> {msg, run};
event_to_msg(#dui_event{type = key, key = start_timer}, _State) -> {msg, start_timer};
event_to_msg(#dui_event{type = key, key = cancel_timer}, _State) -> {msg, cancel_timer};
event_to_msg(#dui_event{type = key, key = Key}, _State) -> {msg, {key, Key}};
event_to_msg(#dui_event{type = custom, key = command_result,
                        content = {_Cid, Result}}, _State) ->
    {msg, {command_result, Result}};
event_to_msg(#dui_event{type = custom, key = parent, content = Msg}, _State) ->
    {msg, Msg};
event_to_msg(#dui_event{type = resize, width = W, height = H}, _State) ->
    {msg, {resize, W, H}};
event_to_msg(_Event, _State) -> ignore.

-spec update(term(), map()) -> {map(), [term()]}.
update(run, State) ->
    {State, [educkui_command:exec(fun() -> 42 end)]};
update({command_result, Result}, State) ->
    {State#{result := Result}, []};
update(start_timer, State) ->
    Ref = make_ref(),
    {State#{timer := Ref, ticks := 0},
     [educkui_command:interval(Ref, tick, 25)]};
update(cancel_timer, State) ->
    case maps:get(timer, State, undefined) of
        undefined -> {State, []};
        Ref -> {State, [educkui_command:cancel_interval(Ref)]}
    end;
update(tick, State) ->
    {State#{ticks := maps:get(ticks, State) + 1}, []};
update({resize, W, H}, State) ->
    {State#{size := {W, H}}, []};
update({key, Key}, State) ->
    {State#{last_key := Key}, []};
update(_Msg, State) ->
    {State, []}.

-spec view(map()) -> #dui_node{}.
view(State) ->
    Text = iolist_to_binary(io_lib:format("~p/~p/~p",
        [maps:get(result, State), maps:get(ticks, State), maps:get(size, State)])),
    educkui_render_node:text(Text).
