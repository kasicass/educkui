%% @doc A stateful scrollable list with keyboard navigation.
%%
%% Props: `{items, [binary()]}` (required), `{height, pos_integer()}`
%% (viewport height, default 10), `{selected, non_neg_integer()}`.
%%
%% Up/Down move the selection, PageUp/PageDown/Home/End scroll, and the
%% offset is kept so the selected item is always visible.
-module(educkui_widget_scrollable_list).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

%% ---------------------------------------------------------------------------
%% init
%% ---------------------------------------------------------------------------

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    Items = proplists:get_value(items, Opts, []),
    Height = max(1, proplists:get_value(height, Opts, 10)),
    #{items => Items,
      height => Height,
      selected => 0,
      offset => 0,
      focused => false}.

%% ---------------------------------------------------------------------------
%% event_to_msg
%% ---------------------------------------------------------------------------

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = up}, _State) -> {msg, up};
event_to_msg(#dui_event{type = key, key = down}, _State) -> {msg, down};
event_to_msg(#dui_event{type = key, key = page_up}, _State) -> {msg, page_up};
event_to_msg(#dui_event{type = key, key = page_down}, _State) -> {msg, page_down};
event_to_msg(#dui_event{type = key, key = home}, _State) -> {msg, home};
event_to_msg(#dui_event{type = key, key = 'end'}, _State) -> {msg, 'end'};
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(_Event, _State) -> ignore.

%% ---------------------------------------------------------------------------
%% update
%% ---------------------------------------------------------------------------

-spec update(term(), map()) -> {map(), [term()]}.
update(up, State) ->
    State1 = State#{selected := max(0, maps:get(selected, State) - 1)},
    {ensure_visible(State1), []};
update(down, State) ->
    Max = max(0, length(maps:get(items, State)) - 1),
    State1 = State#{selected := min(Max, maps:get(selected, State) + 1)},
    {ensure_visible(State1), []};
update(page_up, State) ->
    Step = maps:get(height, State),
    State1 = State#{selected := max(0, maps:get(selected, State) - Step)},
    {ensure_visible(State1), []};
update(page_down, State) ->
    Max = max(0, length(maps:get(items, State)) - 1),
    Step = maps:get(height, State),
    State1 = State#{selected := min(Max, maps:get(selected, State) + Step)},
    {ensure_visible(State1), []};
update(home, State) ->
    {State#{selected := 0, offset := 0}, []};
update('end', State) ->
    Max = max(0, length(maps:get(items, State)) - 1),
    {ensure_visible(State#{selected := Max}), []};
update(focus_gained, State) ->
    {State#{focused := true}, []};
update(focus_lost, State) ->
    {State#{focused := false}, []};
update(_Msg, State) ->
    {State, []}.

%% ---------------------------------------------------------------------------
%% view
%% ---------------------------------------------------------------------------

-spec view(map()) -> #dui_node{}.
view(State) ->
    Items = maps:get(items, State),
    Height = maps:get(height, State),
    Offset = maps:get(offset, State),
    Selected = maps:get(selected, State),
    Visible = lists:sublist(lists:nthtail(Offset, Items), Height),
    Nodes = lists:map(
        fun({Item, I}) ->
            Style = case I =:= Selected of
                true -> educkui_style:from([{reverse, true}]);
                false -> undefined
            end,
            educkui_render_node:text(Item, Style)
        end,
        lists:zip(Visible, lists:seq(Offset, Offset + length(Visible) - 1))),
    educkui_render_node:stack(vertical, Nodes).

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec ensure_visible(map()) -> map().
ensure_visible(State) ->
    Height = maps:get(height, State),
    Selected = maps:get(selected, State),
    Offset = maps:get(offset, State),
    NewOffset =
        if
            Selected < Offset -> Selected;
            Selected >= Offset + Height -> Selected - Height + 1;
            true -> Offset
        end,
    State#{offset := max(0, NewOffset)}.
