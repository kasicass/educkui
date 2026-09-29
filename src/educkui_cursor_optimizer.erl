%% @doc Optimizes cursor movement by selecting the cheapest movement option.
%%
%% Instead of always using absolute positioning (`ESC[r;cH`), the optimizer
%% computes the byte cost of absolute, relative, carriage-return, home and
%% space-based movement and picks the minimum. This can cut cursor movement
%% bytes significantly compared to naive positioning.
-module(educkui_cursor_optimizer).

-include("educkui.hrl").

-export([
    new/0, new/2,
    move_to/3,
    advance/2,
    position/1,
    bytes_saved/1,
    reset/1,
    max_position/0,
    cost_absolute/2,
    cost_up/1, cost_down/1, cost_right/1, cost_left/1,
    optimal_move/4
]).

-define(SPACE_THRESHOLD, 3).
-define(MAX_CURSOR_POS, 9999).

%% ---------------------------------------------------------------------------
%% Construction / queries
%% ---------------------------------------------------------------------------

-spec new() -> #dui_cursor{}.
new() -> #dui_cursor{}.

-spec new(pos_integer(), pos_integer()) -> #dui_cursor{}.
new(Row, Col) when Row >= 1, Col >= 1 ->
    #dui_cursor{row = Row, col = Col}.

-spec position(#dui_cursor{}) -> {pos_integer(), pos_integer()}.
position(#dui_cursor{row = Row, col = Col}) -> {Row, Col}.

-spec bytes_saved(#dui_cursor{}) -> non_neg_integer().
bytes_saved(#dui_cursor{bytes_saved = Saved}) -> Saved.

-spec reset(#dui_cursor{}) -> #dui_cursor{}.
reset(C) -> C#dui_cursor{row = 1, col = 1}.

-spec max_position() -> pos_integer().
max_position() -> ?MAX_CURSOR_POS.

%% ---------------------------------------------------------------------------
%% Movement
%% ---------------------------------------------------------------------------

-spec move_to(#dui_cursor{}, pos_integer(), pos_integer()) -> {iodata(), #dui_cursor{}}.
move_to(#dui_cursor{row = Row, col = Col} = C, Row, Col) ->
    {[], C};
move_to(#dui_cursor{row = Row, col = Col, bytes_saved = Saved} = C,
        TargetRow, TargetCol) ->
    {Sequence, Cost} = optimal_move(Row, Col, TargetRow, TargetCol),
    NaiveCost = cost_absolute(TargetRow, TargetCol),
    Gained = max(0, NaiveCost - Cost),
    {Sequence, C#dui_cursor{
        row = TargetRow,
        col = TargetCol,
        bytes_saved = Saved + Gained
    }}.

-spec advance(#dui_cursor{}, non_neg_integer()) -> #dui_cursor{}.
advance(#dui_cursor{col = Col} = C, Cols) ->
    C#dui_cursor{col = min(Col + Cols, ?MAX_CURSOR_POS)}.

%% ---------------------------------------------------------------------------
%% Cost helpers
%% ---------------------------------------------------------------------------

-spec cost_absolute(pos_integer(), pos_integer()) -> pos_integer().
cost_absolute(Row, Col) ->
    4 + digits(Row) + digits(Col).

-spec cost_up(pos_integer()) -> pos_integer().
cost_up(1) -> 3;
cost_up(N) when N > 1 -> 3 + digits(N).

-spec cost_down(pos_integer()) -> pos_integer().
cost_down(1) -> 3;
cost_down(N) when N > 1 -> 3 + digits(N).

-spec cost_right(pos_integer()) -> pos_integer().
cost_right(1) -> 3;
cost_right(N) when N > 1 -> 3 + digits(N).

-spec cost_left(pos_integer()) -> pos_integer().
cost_left(1) -> 3;
cost_left(N) when N > 1 -> 3 + digits(N).

-spec optimal_move(pos_integer(), pos_integer(), pos_integer(), pos_integer()) ->
    {iodata(), pos_integer()}.
optimal_move(FromRow, FromCol, ToRow, ToCol) ->
    Options = generate_options(FromRow, FromCol, ToRow, ToCol),
    {Seq, Cost} = lists:foldl(
        fun({S, C}, {BestS, BestC}) ->
            case C < BestC of
                true -> {S, C};
                false -> {BestS, BestC}
            end
        end,
        hd(Options),
        tl(Options)),
    {Seq, Cost}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec generate_options(pos_integer(), pos_integer(), pos_integer(), pos_integer()) ->
    [{iodata(), pos_integer()}].
generate_options(FromRow, FromCol, ToRow, ToCol) ->
    RowDiff = ToRow - FromRow,
    ColDiff = ToCol - FromCol,
    [absolute_option(ToRow, ToCol)]
        ++ relative_option(RowDiff, ColDiff)
        ++ cr_options(ToCol, RowDiff)
        ++ cr_col_options(RowDiff, ToCol)
        ++ home_option(ToRow, ToCol)
        ++ space_option(RowDiff, ColDiff)
        ++ newline_options(RowDiff, FromCol, ToCol).

-spec absolute_option(pos_integer(), pos_integer()) -> {iodata(), pos_integer()}.
absolute_option(Row, Col) ->
    Seq = ["\e[", integer_to_list(Row), ";", integer_to_list(Col), "H"],
    {Seq, cost_absolute(Row, Col)}.

-spec relative_option(integer(), integer()) -> [{iodata(), pos_integer()}].
relative_option(0, 0) -> [];
relative_option(RowDiff, ColDiff) ->
    {VSeq, VCost} = vertical_sequence(RowDiff),
    {HSeq, HCost} = horizontal_sequence(ColDiff),
    case VCost + HCost < 100 of
        true -> [{[VSeq, HSeq], VCost + HCost}];
        false -> []
    end.

-spec cr_options(integer(), integer()) -> [{iodata(), pos_integer()}].
cr_options(1, RowDiff) ->
    {VSeq, VCost} = vertical_sequence(RowDiff),
    [{[$\r, VSeq], 1 + VCost}];
cr_options(_ToCol, _RowDiff) ->
    [].

-spec cr_col_options(integer(), pos_integer()) -> [{iodata(), pos_integer()}].
cr_col_options(RowDiff, ToCol) when ToCol > 1 ->
    {VSeq, VCost} = vertical_sequence(RowDiff),
    HDiff = ToCol - 1,
    case HDiff > 0 andalso HDiff =< ?SPACE_THRESHOLD of
        true ->
            [{[$\r, VSeq, lists:duplicate(HDiff, $\s)], 1 + VCost + HDiff}];
        false ->
            {HSeq, HCost} = horizontal_sequence(HDiff),
            [{[$\r, VSeq, HSeq], 1 + VCost + HCost}]
    end;
cr_col_options(_RowDiff, _ToCol) ->
    [].

-spec home_option(pos_integer(), pos_integer()) -> [{iodata(), pos_integer()}].
home_option(1, 1) ->
    [{"\e[H", 3}];
home_option(_ToRow, _ToCol) ->
    [].

-spec space_option(integer(), integer()) -> [{iodata(), pos_integer()}].
space_option(0, ColDiff) when ColDiff > 0, ColDiff =< ?SPACE_THRESHOLD ->
    [{lists:duplicate(ColDiff, $\s), ColDiff}];
space_option(_RowDiff, _ColDiff) ->
    [].

%% Bare `\n` is avoided: with OPOST disabled in raw mode it does not return
%% the carriage, causing staircase rendering. Use ANSI cursor-down instead.
-spec newline_options(integer(), pos_integer(), pos_integer()) ->
    [{iodata(), pos_integer()}].
newline_options(RowDiff, 1, 1) when RowDiff > 0 ->
    {VSeq, VCost} = vertical_sequence(RowDiff),
    [{VSeq, VCost}];
newline_options(_RowDiff, _FromCol, _ToCol) ->
    [].

-spec vertical_sequence(integer()) -> {iodata(), pos_integer()}.
vertical_sequence(0) -> {[], 0};
vertical_sequence(N) when N > 0 ->
    case N of
        1 -> {"\e[B", 3};
        _ -> {["\e[", integer_to_list(N), "B"], cost_down(N)}
    end;
vertical_sequence(N) when N < 0 ->
    Abs = abs(N),
    case Abs of
        1 -> {"\e[A", 3};
        _ -> {["\e[", integer_to_list(Abs), "A"], cost_up(Abs)}
    end.

-spec horizontal_sequence(integer()) -> {iodata(), pos_integer()}.
horizontal_sequence(0) -> {[], 0};
horizontal_sequence(N) when N > 0 ->
    case N of
        1 -> {"\e[C", 3};
        _ -> {["\e[", integer_to_list(N), "C"], cost_right(N)}
    end;
horizontal_sequence(N) when N < 0 ->
    Abs = abs(N),
    case Abs of
        1 -> {"\e[D", 3};
        _ -> {["\e[", integer_to_list(Abs), "D"], cost_left(Abs)}
    end.

-spec digits(non_neg_integer()) -> pos_integer().
digits(N) when N < 10 -> 1;
digits(N) when N < 100 -> 2;
digits(N) when N < 1000 -> 3;
digits(N) -> length(integer_to_list(N)).
