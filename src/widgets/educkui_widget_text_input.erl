%% @doc A stateful single-line text input widget.
%%
%% Implements The Elm Architecture: `init/1' takes `{value, Binary}' and
%% optionally `{placeholder, Binary}'; `event_to_msg/2' maps keys and focus
%% events to messages; `update/2' maintains `value' and `cursor' (both in
%% grapheme counts); `view/1' renders the value with a reverse-video cursor
%% cell when focused.
-module(educkui_widget_text_input).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

%% ---------------------------------------------------------------------------
%% init
%% ---------------------------------------------------------------------------

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    Value = proplists:get_value(value, Opts, <<>>),
    #{value => Value, cursor => string:length(Value), focused => false}.

%% ---------------------------------------------------------------------------
%% event_to_msg
%% ---------------------------------------------------------------------------

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = Key, char = Char}, _State) ->
    case Key of
        backspace -> {msg, backspace};
        delete -> {msg, delete};
        left -> {msg, cursor_left};
        right -> {msg, cursor_right};
        home -> {msg, cursor_home};
        'end' -> {msg, cursor_end};
        _ ->
            case Char of
                undefined -> ignore;
                _ -> {msg, {insert, Char}}
            end
    end;
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(#dui_event{type = mouse, action = press, x = X}, _State) ->
    {msg, {cursor_set, X}};
event_to_msg(_Event, _State) -> ignore.

%% ---------------------------------------------------------------------------
%% update
%% ---------------------------------------------------------------------------

-spec update(term(), map()) -> {map(), [term()]}.
update({insert, Char}, State) ->
    Value = maps:get(value, State),
    Cursor = maps:get(cursor, State),
    {Left, Right} = split_at(Value, Cursor),
    {State#{value := <<Left/binary, Char/binary, Right/binary>>,
            cursor := Cursor + string:length(Char)}, []};
update(backspace, State) ->
    Value = maps:get(value, State),
    Cursor = maps:get(cursor, State),
    case Cursor > 0 of
        true ->
            {Left, Right} = split_at(Value, Cursor),
            Left2 = string:slice(Left, 0, string:length(Left) - 1),
            {State#{value := <<Left2/binary, Right/binary>>, cursor := Cursor - 1}, []};
        false ->
            {State, []}
    end;
update(delete, State) ->
    Value = maps:get(value, State),
    Cursor = maps:get(cursor, State),
    case Cursor < string:length(Value) of
        true ->
            {Left, Right} = split_at(Value, Cursor),
            Right2 = string:slice(Right, 1),
            {State#{value := <<Left/binary, Right2/binary>>}, []};
        false ->
            {State, []}
    end;
update(cursor_left, State) ->
    {State#{cursor := max(0, maps:get(cursor, State) - 1)}, []};
update(cursor_right, State) ->
    {State#{cursor := min(string:length(maps:get(value, State)),
                          maps:get(cursor, State) + 1)}, []};
update({cursor_set, X}, State) ->
    Max = string:length(maps:get(value, State)),
    {State#{cursor := min(Max, max(0, X))}, []};
update(cursor_home, State) ->
    {State#{cursor := 0}, []};
update(cursor_end, State) ->
    {State#{cursor := string:length(maps:get(value, State))}, []};
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
    Value = maps:get(value, State),
    Cursor = maps:get(cursor, State),
    Focused = maps:get(focused, State),
    Graphemes = string:to_graphemes(Value),
    {Cells, _} = lists:foldl(
        fun(G, {Acc, I}) ->
            Char = unicode:characters_to_binary([G]),
            Cell = case Focused andalso I =:= Cursor of
                true -> educkui_cell:new(Char, [{attrs, [reverse]}]);
                false -> educkui_cell:new(Char)
            end,
            {[{I, 0, Cell} | Acc], I + 1}
        end,
        {[], 0},
        Graphemes),
    Cells1 = lists:reverse(Cells),
    Cells2 = case Focused andalso Cursor >= length(Graphemes) of
        true -> Cells1 ++ [{Cursor, 0, educkui_cell:new(<<" ">>, [{attrs, [reverse]}])}];
        false -> Cells1
    end,
    %% Ensure at least one cell so the widget has a non-zero natural height
    %% (and remains mouse-clickable) even when empty and unfocused.
    FinalCells = case Cells2 of
        [] -> [{0, 0, educkui_cell:new(<<" ">>)}];
        _ -> Cells2
    end,
    educkui_render_node:cells(FinalCells).

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec split_at(binary(), non_neg_integer()) -> {binary(), binary()}.
split_at(Bin, N) ->
    {string:slice(Bin, 0, N), string:slice(Bin, N)}.
