%% @doc ETS-backed screen buffer for storing cells.
%%
%% The buffer uses an ETS `ordered_set` table keyed by `{Row, Col}` tuples
%% (both 1-indexed) for O(log n) access and natural row-major iteration.
%% All cells are initialized to empty, so the buffer is dense and `get_row/2`
%% always returns exactly `cols` cells.
-module(educkui_buffer).

-include("educkui.hrl").

-export([
    new/2,
    max_rows/0, max_cols/0,
    destroy/1,
    get_cell/3,
    set_cell/4,
    set_cells/2,
    clear_region/5,
    clear/1,
    clear_row/2,
    clear_col/2,
    resize/3,
    dimensions/1,
    in_bounds/3,
    each/2,
    to_list/1,
    get_row/2,
    write_string/4
]).

-define(MAX_ROWS, 500).
-define(MAX_COLS, 1000).

%% ---------------------------------------------------------------------------
%% Construction
%% ---------------------------------------------------------------------------

-spec new(pos_integer(), pos_integer()) -> {ok, #dui_buffer{}} | {error, term()}.
new(Rows, Cols) when is_integer(Rows), Rows > 0, is_integer(Cols), Cols > 0 ->
    case Rows > ?MAX_ROWS orelse Cols > ?MAX_COLS of
        true ->
            {error, {dimensions_too_large, Rows, Cols, ?MAX_ROWS, ?MAX_COLS}};
        false ->
            Table = ets:new(dui_buffer, [ordered_set, public]),
            Buffer = #dui_buffer{table = Table, rows = Rows, cols = Cols},
            initialize_cells(Buffer),
            {ok, Buffer}
    end.

-spec max_rows() -> pos_integer().
max_rows() -> ?MAX_ROWS.

-spec max_cols() -> pos_integer().
max_cols() -> ?MAX_COLS.

-spec destroy(#dui_buffer{}) -> ok.
destroy(#dui_buffer{table = Table}) ->
    ets:delete(Table),
    ok.

%% ---------------------------------------------------------------------------
%% Cell access
%% ---------------------------------------------------------------------------

-spec get_cell(#dui_buffer{}, pos_integer(), pos_integer()) -> #dui_cell{}.
get_cell(#dui_buffer{table = Table} = Buffer, Row, Col) ->
    case in_bounds(Buffer, Row, Col) of
        true ->
            case ets:lookup(Table, {Row, Col}) of
                [{{Row, Col}, Cell}] -> Cell;
                [] -> educkui_cell:empty()
            end;
        false ->
            educkui_cell:empty()
    end.

-spec set_cell(#dui_buffer{}, pos_integer(), pos_integer(), #dui_cell{}) ->
    ok | {error, out_of_bounds}.
set_cell(#dui_buffer{table = Table} = Buffer, Row, Col, #dui_cell{} = Cell) ->
    case in_bounds(Buffer, Row, Col) of
        true ->
            ets:insert(Table, {{Row, Col}, Cell}),
            ok;
        false ->
            {error, out_of_bounds}
    end.

-spec set_cells(#dui_buffer{}, [{pos_integer(), pos_integer(), #dui_cell{}}]) -> ok.
set_cells(#dui_buffer{table = Table} = Buffer, Cells) when is_list(Cells) ->
    Entries = [{{Row, Col}, Cell} || {Row, Col, Cell} <- Cells, in_bounds(Buffer, Row, Col)],
    ets:insert(Table, Entries),
    ok.

%% ---------------------------------------------------------------------------
%% Clearing
%% ---------------------------------------------------------------------------

-spec clear_region(#dui_buffer{}, pos_integer(), pos_integer(),
    non_neg_integer(), non_neg_integer()) -> ok.
clear_region(#dui_buffer{table = Table} = Buffer, StartRow, StartCol, Width, Height)
        when is_integer(Width), Width > 0, is_integer(Height), Height > 0 ->
    Empty = educkui_cell:empty(),
    Entries = [{{Row, Col}, Empty}
               || Row <- lists:seq(StartRow, StartRow + Height - 1),
                  Col <- lists:seq(StartCol, StartCol + Width - 1),
                  in_bounds(Buffer, Row, Col)],
    ets:insert(Table, Entries),
    ok;
clear_region(#dui_buffer{}, _StartRow, _StartCol, _Width, _Height) ->
    ok.

-spec clear(#dui_buffer{}) -> ok.
clear(#dui_buffer{rows = Rows, cols = Cols} = Buffer) ->
    clear_region(Buffer, 1, 1, Cols, Rows).

-spec clear_row(#dui_buffer{}, pos_integer()) -> ok.
clear_row(#dui_buffer{cols = Cols} = Buffer, Row) ->
    clear_region(Buffer, Row, 1, Cols, 1).

-spec clear_col(#dui_buffer{}, pos_integer()) -> ok.
clear_col(#dui_buffer{rows = Rows} = Buffer, Col) ->
    clear_region(Buffer, 1, Col, 1, Rows).

%% ---------------------------------------------------------------------------
%% Resize
%% ---------------------------------------------------------------------------

-spec resize(#dui_buffer{}, pos_integer(), pos_integer()) ->
    {ok, #dui_buffer{}} | {error, term()}.
resize(#dui_buffer{} = Buffer, NewRows, NewCols)
        when is_integer(NewRows), NewRows > 0, is_integer(NewCols), NewCols > 0 ->
    case NewRows > ?MAX_ROWS orelse NewCols > ?MAX_COLS of
        true ->
            {error, {dimensions_too_large, NewRows, NewCols, ?MAX_ROWS, ?MAX_COLS}};
        false ->
            {ok, NewBuffer} = new(NewRows, NewCols),
            CopyRows = min(Buffer#dui_buffer.rows, NewRows),
            CopyCols = min(Buffer#dui_buffer.cols, NewCols),
            CopyEntries = [{{Row, Col}, get_cell(Buffer, Row, Col)}
                           || Row <- lists:seq(1, CopyRows),
                              Col <- lists:seq(1, CopyCols)],
            ets:insert(NewBuffer#dui_buffer.table, CopyEntries),
            destroy(Buffer),
            {ok, NewBuffer}
    end.

%% ---------------------------------------------------------------------------
%% Queries
%% ---------------------------------------------------------------------------

-spec dimensions(#dui_buffer{}) -> {pos_integer(), pos_integer()}.
dimensions(#dui_buffer{rows = Rows, cols = Cols}) ->
    {Rows, Cols}.

-spec in_bounds(#dui_buffer{}, pos_integer(), pos_integer()) -> boolean().
in_bounds(#dui_buffer{rows = Rows, cols = Cols}, Row, Col) ->
    Row >= 1 andalso Row =< Rows andalso Col >= 1 andalso Col =< Cols.

-spec each(#dui_buffer{}, fun(({pos_integer(), pos_integer(), #dui_cell{}}) -> term())) -> ok.
each(#dui_buffer{table = Table}, Fun) when is_function(Fun, 1) ->
    ets:foldl(
        fun({{Row, Col}, Cell}, _Acc) ->
            Fun({Row, Col, Cell}),
            ok
        end,
        ok,
        Table),
    ok.

-spec to_list(#dui_buffer{}) -> [{pos_integer(), pos_integer(), #dui_cell{}}].
to_list(#dui_buffer{table = Table}) ->
    [{Row, Col, Cell} || {{Row, Col}, Cell} <- ets:tab2list(Table)].

-spec get_row(#dui_buffer{}, pos_integer()) -> [#dui_cell{}].
get_row(#dui_buffer{table = Table, rows = Rows}, Row)
        when Row >= 1, Row =< Rows ->
    Objects = ets:match_object(Table, {{Row, '_'}, '_'}),
    Sorted = lists:keysort(1, [{Col, Cell} || {{_R, Col}, Cell} <- Objects]),
    [Cell || {_Col, Cell} <- Sorted];
get_row(#dui_buffer{cols = Cols}, _Row) ->
    [educkui_cell:empty() || _ <- lists:seq(1, Cols)].

%% ---------------------------------------------------------------------------
%% String writing
%% ---------------------------------------------------------------------------

-spec write_string(#dui_buffer{}, pos_integer(), pos_integer(), binary()) ->
    non_neg_integer().
write_string(#dui_buffer{} = Buffer, Row, Col, String) when is_binary(String) ->
    Graphemes = string:to_graphemes(String),
    EndCol = lists:foldl(
        fun(Grapheme, CurrentCol) ->
            write_grapheme(Buffer, Row, CurrentCol, Grapheme)
        end,
        Col,
        Graphemes),
    EndCol - Col.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec initialize_cells(#dui_buffer{}) -> ok.
initialize_cells(#dui_buffer{table = Table, rows = Rows, cols = Cols}) ->
    Empty = educkui_cell:empty(),
    lists:foreach(
        fun(Row) ->
            Entries = [{{Row, Col}, Empty} || Col <- lists:seq(1, Cols)],
            ets:insert(Table, Entries)
        end,
        lists:seq(1, Rows)),
    ok.

-spec write_grapheme(#dui_buffer{}, pos_integer(), pos_integer(), char() | [char()]) ->
    pos_integer().
write_grapheme(#dui_buffer{} = Buffer, Row, CurrentCol, Grapheme) ->
    case in_bounds(Buffer, Row, CurrentCol) of
        true ->
            Char = unicode:characters_to_binary([Grapheme]),
            Cell = educkui_cell:new(Char),
            _ = set_cell(Buffer, Row, CurrentCol, Cell),
            write_wide_placeholder(Buffer, Row, CurrentCol, Cell),
            CurrentCol + educkui_cell:width(Cell);
        false ->
            CurrentCol
    end.

-spec write_wide_placeholder(#dui_buffer{}, pos_integer(), pos_integer(), #dui_cell{}) -> ok.
write_wide_placeholder(#dui_buffer{table = Table} = Buffer, Row, Col, Cell) ->
    case educkui_cell:wide(Cell) andalso in_bounds(Buffer, Row, Col + 1) of
        true ->
            ets:insert(Table, {{Row, Col + 1}, educkui_cell:wide_placeholder(Cell)}),
            ok;
        false ->
            ok
    end.
