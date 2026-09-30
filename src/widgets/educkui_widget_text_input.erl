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
    edit(fun(LE) -> educkui_lineedit:insert(Char, LE) end, State);
update(backspace, State) ->
    edit(fun educkui_lineedit:backspace/1, State);
update(delete, State) ->
    edit(fun educkui_lineedit:delete/1, State);
update(cursor_left, State) ->
    edit(fun(LE) -> educkui_lineedit:move(left, LE) end, State);
update(cursor_right, State) ->
    edit(fun(LE) -> educkui_lineedit:move(right, LE) end, State);
update({cursor_set, X}, State) ->
    edit(fun(LE) -> educkui_lineedit:set_cursor(max(0, X), LE) end, State);
update(cursor_home, State) ->
    edit(fun educkui_lineedit:home/1, State);
update(cursor_end, State) ->
    edit(fun educkui_lineedit:'end'/1, State);
update(focus_gained, State) ->
    {State#{focused := true}, []};
update(focus_lost, State) ->
    {State#{focused := false}, []};
update(_Msg, State) ->
    {State, []}.

%% @doc Applies a line-edit operation to the widget's `value'/`cursor' fields.
-spec edit(fun((educkui_lineedit:state()) -> educkui_lineedit:state()), map()) ->
    {map(), [term()]}.
edit(Fun, State) ->
    LE = educkui_lineedit:new(maps:get(value, State), maps:get(cursor, State)),
    LE1 = Fun(LE),
    {State#{value := educkui_lineedit:value(LE1),
            cursor := educkui_lineedit:cursor(LE1)}, []}.

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
