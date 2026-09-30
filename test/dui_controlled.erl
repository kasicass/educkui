%% @doc Controlled-component fixture: mounts a text input and a settings
%% component so `educkui_runtime:set_props/3' can be exercised.
-module(dui_controlled).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

-spec init([{atom(), term()}]) -> map().
init(_Opts) -> #{}.

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(_Event, _State) -> ignore.

-spec update(term(), map()) -> {map(), [term()]}.
update(_Msg, State) -> {State, []}.

-spec view(map()) -> #dui_node{}.
view(_State) ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:component(input, educkui_widget_text_input,
                                      #{value => <<"a">>}),
        educkui_render_node:component(settings, dui_settings, #{count => 0})
    ]).
