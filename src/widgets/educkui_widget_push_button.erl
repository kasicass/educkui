%% @doc A stateful push-button widget.
%%
%% Props: `{label, binary()}', `{id, term()}'. Enter/Space activate the button,
%% sending `{parent, {button, Id}}' to the root component; Esc propagates.
-module(educkui_widget_push_button).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    #{label => proplists:get_value(label, Opts, <<>>),
      id => proplists:get_value(id, Opts),
      focused => false}.

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = enter}, _State) -> {msg, activate};
event_to_msg(#dui_event{type = key, key = <<" ">>}, _State) -> {msg, activate};
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(_Event, _State) -> ignore.

-spec update(term(), map()) -> {map(), [term()]}.
update(activate, State) ->
    {State, [{parent, {button, maps:get(id, State)}}]};
update(focus_gained, State) ->
    {State#{focused := true}, []};
update(focus_lost, State) ->
    {State#{focused := false}, []};
update(_Msg, State) ->
    {State, []}.

-spec view(map()) -> #dui_node{}.
view(State) ->
    Label = maps:get(label, State),
    Focused = maps:get(focused, State),
    Style = case Focused of
        true -> educkui_style:from([{reverse, true}, {bold, true}]);
        false -> educkui_style:from([{bold, true}])
    end,
    educkui_render_node:text(<<"[", Label/binary, "]">>, Style).
