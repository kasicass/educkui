%% @doc Minimal controlled component implementing `handle_props/2'.
-module(dui_settings).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1, handle_props/2]).

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    #{count => proplists:get_value(count, Opts, 0)}.

-spec handle_props(map(), map()) -> {map(), [term()]} | ignore.
handle_props(#{count := Count}, _State) ->
    {#{count => Count}, []};
handle_props(_Props, _State) ->
    ignore.

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(_Event, _State) -> ignore.

-spec update(term(), map()) -> {map(), [term()]}.
update(_Msg, State) -> {State, []}.

-spec view(map()) -> #dui_node{}.
view(State) ->
    educkui_render_node:text(integer_to_binary(maps:get(count, State))).
