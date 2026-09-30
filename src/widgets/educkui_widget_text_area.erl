%% @doc A stateful multi-line text area widget.
%%
%% State holds a list of lines plus the cursor position (row, column) in
%% grapheme counts. Supports character insertion, newline (Enter), backspace,
%% delete, arrow-key movement, Home/End, and focus highlighting.
-module(educkui_widget_text_area).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1, handle_props/2]).

%% ---------------------------------------------------------------------------
%% init
%% ---------------------------------------------------------------------------

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    Value = proplists:get_value(value, Opts, <<>>),
    Lines = binary:split(Value, <<"\n">>, [global]),
    #{lines => Lines,
      row => length(Lines) - 1,
      col => string:length(lists:last(Lines)),
      focused => false}.

%% ---------------------------------------------------------------------------
%% handle_props
%% ---------------------------------------------------------------------------

-spec handle_props(map(), map()) -> {map(), [term()]} | ignore.
handle_props(Props, State) ->
    case maps:get(value, Props, undefined) of
        Value when is_binary(Value) ->
            Lines = binary:split(Value, <<"\n">>, [global]),
            {State#{lines := Lines,
                    row := length(Lines) - 1,
                    col := string:length(lists:last(Lines))}, []};
        _ ->
            ignore
    end.

%% ---------------------------------------------------------------------------
%% event_to_msg
%% ---------------------------------------------------------------------------

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = Key, char = Char}, _State) ->
    case Key of
        enter -> {msg, newline};
        backspace -> {msg, backspace};
        delete -> {msg, delete};
        left -> {msg, left};
        right -> {msg, right};
        up -> {msg, up};
        down -> {msg, down};
        home -> {msg, home};
        'end' -> {msg, 'end'};
        _ ->
            case Char of
                undefined -> ignore;
                _ -> {msg, {insert, Char}}
            end
    end;
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(_Event, _State) -> ignore.

%% ---------------------------------------------------------------------------
%% update
%% ---------------------------------------------------------------------------

-spec update(term(), map()) -> {map(), [term()]}.
update({insert, Char}, State) ->
    {Row, Col} = cursor(State),
    Lines = maps:get(lines, State),
    Line = lists:nth(Row + 1, Lines),
    {L, R} = split_at(Line, Col),
    NewLine = <<L/binary, Char/binary, R/binary>>,
    {State#{lines := set_nth(Row, NewLine, Lines), col := Col + string:length(Char)}, []};

update(newline, State) ->
    {Row, Col} = cursor(State),
    Lines = maps:get(lines, State),
    Line = lists:nth(Row + 1, Lines),
    {L, R} = split_at(Line, Col),
    NewLines = set_nth(Row, L, Lines),
    {State#{lines := insert_after(Row, R, NewLines), row := Row + 1, col := 0}, []};

update(backspace, State) ->
    {Row, Col} = cursor(State),
    Lines = maps:get(lines, State),
    case Col > 0 of
        true ->
            Line = lists:nth(Row + 1, Lines),
            {L, R} = split_at(Line, Col),
            L2 = string:slice(L, 0, string:length(L) - 1),
            {State#{lines := set_nth(Row, <<L2/binary, R/binary>>, Lines),
                    col := Col - 1}, []};
        false ->
            case Row > 0 of
                true ->
                    Prev = lists:nth(Row, Lines),
                    Current = lists:nth(Row + 1, Lines),
                    Joined = <<Prev/binary, Current/binary>>,
                    Lines2 = set_nth(Row - 1, Joined, delete_at(Row, Lines)),
                    {State#{lines := Lines2, row := Row - 1,
                            col := string:length(Prev)}, []};
                false ->
                    {State, []}
            end
    end;

update(delete, State) ->
    {Row, Col} = cursor(State),
    Lines = maps:get(lines, State),
    Line = lists:nth(Row + 1, Lines),
    case Col < string:length(Line) of
        true ->
            {L, R} = split_at(Line, Col),
            R2 = string:slice(R, 1),
            {State#{lines := set_nth(Row, <<L/binary, R2/binary>>, Lines)}, []};
        false ->
            case Row + 1 < length(Lines) of
                true ->
                    Next = lists:nth(Row + 2, Lines),
                    Joined = <<Line/binary, Next/binary>>,
                    Lines2 = set_nth(Row, Joined, delete_at(Row + 1, Lines)),
                    {State#{lines := Lines2}, []};
                false ->
                    {State, []}
            end
    end;

update(left, State) ->
    {Row, Col} = cursor(State),
    case Col > 0 of
        true -> {State#{col := Col - 1}, []};
        false ->
            case Row > 0 of
                true -> {State#{row := Row - 1,
                                col := string:length(lists:nth(Row, maps:get(lines, State)))}, []};
                false -> {State, []}
            end
    end;

update(right, State) ->
    {Row, Col} = cursor(State),
    Line = lists:nth(Row + 1, maps:get(lines, State)),
    case Col < string:length(Line) of
        true -> {State#{col := Col + 1}, []};
        false ->
            case Row + 1 < length(maps:get(lines, State)) of
                true -> {State#{row := Row + 1, col := 0}, []};
                false -> {State, []}
            end
    end;

update(up, State) ->
    {Row, Col} = cursor(State),
    case Row > 0 of
        true -> {State#{row := Row - 1,
                        col := min(Col, string:length(lists:nth(Row, maps:get(lines, State))))}, []};
        false -> {State#{col := 0}, []}
    end;

update(down, State) ->
    {Row, Col} = cursor(State),
    Lines = maps:get(lines, State),
    case Row + 1 < length(Lines) of
        true -> {State#{row := Row + 1,
                        col := min(Col, string:length(lists:nth(Row + 2, Lines)))}, []};
        false -> {State#{col := string:length(lists:last(Lines))}, []}
    end;

update(home, State) ->
    {State#{col := 0}, []};
update('end', State) ->
    {Row, _Col} = cursor(State),
    Line = lists:nth(Row + 1, maps:get(lines, State)),
    {State#{col := string:length(Line)}, []};
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
    Lines = maps:get(lines, State),
    Focused = maps:get(focused, State),
    {Row, Col} = cursor(State),
    Nodes = lists:map(
        fun({Line, I}) ->
            case Focused andalso I =:= Row of
                true -> line_with_cursor(Line, Col);
                false -> educkui_render_node:text(Line)
            end
        end,
        lists:zip(Lines, lists:seq(0, length(Lines) - 1))),
    educkui_render_node:stack(vertical, Nodes).

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec cursor(map()) -> {non_neg_integer(), non_neg_integer()}.
cursor(State) ->
    {maps:get(row, State), maps:get(col, State)}.

-spec line_with_cursor(binary(), non_neg_integer()) -> #dui_node{}.
line_with_cursor(Line, Col) ->
    Graphemes = string:to_graphemes(Line),
    {Cells, _} = lists:foldl(
        fun(G, {Acc, I}) ->
            Char = unicode:characters_to_binary([G]),
            Cell = case I =:= Col of
                true -> educkui_cell:new(Char, [{attrs, [reverse]}]);
                false -> educkui_cell:new(Char)
            end,
            {[{I, 0, Cell} | Acc], I + 1}
        end,
        {[], 0},
        Graphemes),
    Cells1 = lists:reverse(Cells),
    Cells2 = case Col >= length(Graphemes) of
        true -> Cells1 ++ [{Col, 0, educkui_cell:new(<<" ">>, [{attrs, [reverse]}])}];
        false -> Cells1
    end,
    educkui_render_node:cells(Cells2).

-spec split_at(binary(), non_neg_integer()) -> {binary(), binary()}.
split_at(Bin, N) ->
    {string:slice(Bin, 0, N), string:slice(Bin, N)}.

-spec set_nth(non_neg_integer(), term(), [term()]) -> [term()].
set_nth(I, Value, List) ->
    {A, [_ | B]} = lists:split(I, List),
    A ++ [Value | B].

-spec insert_after(non_neg_integer(), term(), [term()]) -> [term()].
insert_after(I, Value, List) ->
    {A, B} = lists:split(I + 1, List),
    A ++ [Value | B].

-spec delete_at(non_neg_integer(), [term()]) -> [term()].
delete_at(I, List) ->
    {A, [_ | B]} = lists:split(I, List),
    A ++ B.
