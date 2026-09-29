%% @doc A stateful tabs widget.
%%
%% Props: `{tabs, [{Title :: binary(), Content :: #dui_node{}}]}`. Left/Right
%% switch the active tab; the active tab's title is highlighted and its
%% content is rendered below the tab bar.
-module(educkui_widget_tabs).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    Tabs = proplists:get_value(tabs, Opts, []),
    #{tabs => Tabs, active => 0, focused => false}.

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = left}, _State) -> {msg, prev};
event_to_msg(#dui_event{type = key, key = right}, _State) -> {msg, next};
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(_Event, _State) -> ignore.

-spec update(term(), map()) -> {map(), [term()]}.
update(prev, State) ->
    N = length(maps:get(tabs, State)),
    Active = case N of
        0 -> 0;
        _ -> (maps:get(active, State) - 1 + N) rem N
    end,
    {State#{active := Active}, []};
update(next, State) ->
    N = length(maps:get(tabs, State)),
    Active = case N of
        0 -> 0;
        _ -> (maps:get(active, State) + 1) rem N
    end,
    {State#{active := Active}, []};
update(focus_gained, State) ->
    {State#{focused := true}, []};
update(focus_lost, State) ->
    {State#{focused := false}, []};
update(_Msg, State) ->
    {State, []}.

-spec view(map()) -> #dui_node{}.
view(State) ->
    Tabs = maps:get(tabs, State),
    Active = maps:get(active, State),
    Titles = lists:map(
        fun({{Title, _Content}, I}) ->
            Style = case I =:= Active of
                true -> educkui_style:from([{reverse, true}]);
                false -> undefined
            end,
            educkui_render_node:text(Title, Style)
        end,
        lists:zip(Tabs, lists:seq(0, max(0, length(Tabs) - 1)))),
    Header = educkui_render_node:stack(horizontal, Titles),
    Content = case Tabs of
        [] -> educkui_render_node:empty();
        _ -> element(2, lists:nth(min(length(Tabs), Active + 1), Tabs))
    end,
    educkui_render_node:stack(vertical, [Header, Content]).
