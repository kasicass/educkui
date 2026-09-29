%% @doc A stateful inline pick-list widget with type-ahead filtering.
%%
%% Implements The Elm Architecture. Props: `{items, [binary()]}` (required),
%% `{selected, non_neg_integer()}` (index into items, default 0),
%% `{prompt, binary()}` (default `<<"">>`).
%%
%% When focused:
%% - printable characters filter the item list (case-insensitive substring)
%% - Up/Down move the highlight within the filtered list
%% - Enter commits the highlighted item
%% - Backspace removes the last filter character
%% - Esc propagates (so the application can close/quit)
-module(educkui_widget_pick_list).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

%% ---------------------------------------------------------------------------
%% init
%% ---------------------------------------------------------------------------

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    Items = proplists:get_value(items, Opts, []),
    Selected = proplists:get_value(selected, Opts, 0),
    Prompt = proplists:get_value(prompt, Opts, <<>>),
    #{items => Items,
      selected => clamp_index(Selected, Items),
      prompt => Prompt,
      filter => <<>>,
      highlight => 0,
      focused => false}.

%% ---------------------------------------------------------------------------
%% event_to_msg
%% ---------------------------------------------------------------------------

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = up}, _State) -> {msg, up};
event_to_msg(#dui_event{type = key, key = down}, _State) -> {msg, down};
event_to_msg(#dui_event{type = key, key = enter}, _State) -> {msg, select};
event_to_msg(#dui_event{type = key, key = backspace}, _State) -> {msg, filter_backspace};
event_to_msg(#dui_event{type = key, key = _Key, char = Char}, _State) ->
    case Char of
        undefined -> ignore;
        _ -> {msg, {filter_char, Char}}
    end;
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(_Event, _State) -> ignore.

%% ---------------------------------------------------------------------------
%% update
%% ---------------------------------------------------------------------------

-spec update(term(), map()) -> {map(), [term()]}.
update(up, State) ->
    {State#{highlight := max(0, maps:get(highlight, State) - 1)}, []};
update(down, State) ->
    Filtered = filter_items(State),
    Max = max(0, length(Filtered) - 1),
    {State#{highlight := min(Max, maps:get(highlight, State) + 1)}, []};
update(select, State) ->
    Filtered = filter_items(State),
    case length(Filtered) of
        0 ->
            {State, []};
        _ ->
            Highlight = min(maps:get(highlight, State), length(Filtered) - 1),
            {OriginalIndex, _Text} = lists:nth(Highlight + 1, Filtered),
            {State#{selected := OriginalIndex, filter := <<>>, highlight := 0}, []}
    end;
update(filter_backspace, State) ->
    Filter = maps:get(filter, State),
    case Filter of
        <<>> -> {State, []};
        _ ->
            NewFilter = string:slice(Filter, 0, string:length(Filter) - 1),
            {State#{filter := NewFilter, highlight := 0}, []}
    end;
update({filter_char, Char}, State) ->
    Filter = maps:get(filter, State),
    {State#{filter := <<Filter/binary, Char/binary>>, highlight := 0}, []};
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
    Selected = maps:get(selected, State),
    Prompt = maps:get(prompt, State),
    Focused = maps:get(focused, State),
    SelectedText = case Items of
        [] -> <<>>;
        _ -> lists:nth(min(length(Items), Selected + 1), Items)
    end,

    Header = educkui_render_node:text(
        <<Prompt/binary, SelectedText/binary>>,
        educkui_style:from([{bold, true}])),

    case Focused of
        false ->
            educkui_render_node:stack(vertical, [Header]);
        true ->
            Filtered = filter_items(State),
            Highlight = maps:get(highlight, State),
            ItemNodes = lists:map(
                fun({{_Idx, Text}, I}) ->
                    Style = case I =:= Highlight of
                        true -> educkui_style:from([{reverse, true}]);
                        false -> undefined
                    end,
                    educkui_render_node:text(Text, Style)
                end,
                lists:zip(Filtered, lists:seq(0, max(0, length(Filtered) - 1)))),
            educkui_render_node:stack(vertical, [Header | ItemNodes])
    end.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec filter_items(map()) -> [{non_neg_integer(), binary()}].
filter_items(State) ->
    Items = maps:get(items, State),
    Filter = string:lowercase(maps:get(filter, State)),
    [{I, Item}
     || {I, Item} <- lists:zip(lists:seq(0, length(Items) - 1), Items),
        filter_empty(Filter) orelse
        string:find(string:lowercase(Item), Filter) =/= nomatch].

-spec filter_empty(binary()) -> boolean().
filter_empty(<<>>) -> true;
filter_empty(_) -> false.

-spec clamp_index(integer(), [term()]) -> non_neg_integer().
clamp_index(Index, Items) ->
    case Items of
        [] -> 0;
        _ -> min(max(0, Index), length(Items) - 1)
    end.
