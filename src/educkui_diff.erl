%% @doc Differential rendering algorithm.
%%
%% Compares the current and previous buffers and produces a minimal list of
%% render operations. Changed cells are grouped into spans within each row;
%% adjacent spans separated by a small gap (<= 3 columns) are merged because
%% including the unchanged cells is cheaper than moving the cursor around
%% them. Spans are split by style so SGR sequences are emitted only on style
%% changes.
%%
%% Operation types:
%% - `{move, Row, Col}` - move the cursor (1-indexed)
%% - `{style, Style}`    - set text style
%% - `{text, Binary}`    - output text at the current cursor position
%% - `reset`             - reset all style attributes
-module(educkui_diff).

-include("educkui.hrl").

-export([diff/2, diff_row/3]).

-define(MERGE_GAP_THRESHOLD, 3).

-type operation() ::
    {move, pos_integer(), pos_integer()}
    | {style, #dui_style{}}
    | {text, binary()}
    | reset.
-export_type([operation/0]).

%% A span is {Row, StartCol, EndCol, Cells} where Cells is in forward order.
-type span() :: {pos_integer(), pos_integer(), pos_integer(), [#dui_cell{}]}.

%% ---------------------------------------------------------------------------
%% Public API
%% ---------------------------------------------------------------------------

-spec diff(#dui_buffer{}, #dui_buffer{}) -> [operation()].
diff(#dui_buffer{} = Current, #dui_buffer{} = Previous) ->
    {Rows, _Cols} = educkui_buffer:dimensions(Current),
    Ops = lists:flatmap(
        fun(Row) -> diff_row(Current, Previous, Row) end,
        lists:seq(1, Rows)),
    optimize_operations(Ops).

-spec diff_row(#dui_buffer{}, #dui_buffer{}, pos_integer()) -> [operation()].
diff_row(#dui_buffer{} = Current, #dui_buffer{} = Previous, Row) ->
    CurrentRow = educkui_buffer:get_row(Current, Row),
    PreviousRow = educkui_buffer:get_row(Previous, Row),
    Cols = length(CurrentRow),
    IndexedCurrent = lists:zip(lists:seq(1, Cols), CurrentRow),
    IndexedPrevious = lists:zip(lists:seq(1, Cols), PreviousRow),
    Spans = find_changed_spans(IndexedCurrent, IndexedPrevious, Row),
    Merged = merge_spans(Spans, CurrentRow),
    lists:flatmap(fun span_to_operations/1, Merged).

%% ---------------------------------------------------------------------------
%% Span detection
%% ---------------------------------------------------------------------------

-spec find_changed_spans([{pos_integer(), #dui_cell{}}],
    [{pos_integer(), #dui_cell{}}], pos_integer()) -> [span()].
find_changed_spans(IndexedCurrent, IndexedPrevious, Row) ->
    {RevSpans, OpenSpan} =
        lists:foldl(
            fun({{Col, Curr}, {_Col, Prev}}, {Spans, Span}) ->
                case educkui_cell:equal(Curr, Prev) of
                    true ->
                        case Span of
                            undefined -> {Spans, undefined};
                            _ -> {[finalize_span(Span) | Spans], undefined}
                        end;
                    false ->
                        case Span of
                            undefined -> {Spans, {Row, Col, Col, [Curr]}};
                            {R, S, _E, Cells} -> {Spans, {R, S, Col, [Curr | Cells]}}
                        end
                end
            end,
            {[], undefined},
            lists:zip(IndexedCurrent, IndexedPrevious)),
    Spans = case OpenSpan of
        undefined -> RevSpans;
        _ -> [finalize_span(OpenSpan) | RevSpans]
    end,
    lists:reverse(Spans).

%% ---------------------------------------------------------------------------
%% Span merging
%% ---------------------------------------------------------------------------

-spec merge_spans([span()], [#dui_cell{}]) -> [span()].
merge_spans([], _CurrentRow) -> [];
merge_spans([Span], _CurrentRow) -> [Span];
merge_spans(Spans, CurrentRow) ->
    lists:reverse(
        lists:foldl(
            fun(Span, Acc) -> merge_span(Span, Acc, CurrentRow) end,
            [],
            Spans)).

-spec merge_span(span(), [span()], [#dui_cell{}]) -> [span()].
merge_span(Span, [], _CurrentRow) ->
    [Span];
merge_span({_Row, StartCol, EndCol, Cells} = Span, [Prev | Rest], CurrentRow) ->
    {PRow, PStartCol, PEndCol, PCells} = Prev,
    Gap = StartCol - PEndCol - 1,
    case Gap =< ?MERGE_GAP_THRESHOLD andalso Gap >= 0 of
        true ->
            GapCells = [lists:nth(Col, CurrentRow)
                        || Col <- lists:seq(PEndCol + 1, StartCol - 1)],
            Merged = {PRow, PStartCol, EndCol, PCells ++ GapCells ++ Cells},
            [Merged | Rest];
        false ->
            [Span, Prev | Rest]
    end.

%% ---------------------------------------------------------------------------
%% Span to operations
%% ---------------------------------------------------------------------------

-spec span_to_operations(span()) -> [operation()].
span_to_operations({Row, StartCol, _EndCol, Cells}) ->
    Groups = group_by_style(Cells),
    [reset, {move, Row, StartCol} | style_groups_to_operations(Groups)].

-spec group_by_style([#dui_cell{}]) -> [{#dui_style{}, [#dui_cell{}]}].
group_by_style(Cells) ->
    lists:reverse(lists:foldl(fun add_to_style_group/2, [], Cells)).

-spec add_to_style_group(#dui_cell{}, [{#dui_style{}, [#dui_cell{}]}]) ->
    [{#dui_style{}, [#dui_cell{}]}].
add_to_style_group(Cell, []) ->
    [{cell_to_style(Cell), [Cell]}];
add_to_style_group(Cell, [{Style, Cells} | Rest]) ->
    case educkui_style:equal(Style, cell_to_style(Cell)) of
        true ->
            [{Style, [Cell | Cells]} | Rest];
        false ->
            [{cell_to_style(Cell), [Cell]}, {Style, Cells} | Rest]
    end.

-spec style_groups_to_operations([{#dui_style{}, [#dui_cell{}]}]) -> [operation()].
style_groups_to_operations(Groups) ->
    lists:flatmap(
        fun({Style, Cells}) ->
            Text = iolist_to_binary([C#dui_cell.char || C <- lists:reverse(Cells)]),
            [{style, Style}, {text, Text}]
        end,
        Groups).

-spec cell_to_style(#dui_cell{}) -> #dui_style{}.
cell_to_style(#dui_cell{fg = Fg, bg = Bg, attrs = Attrs}) ->
    #dui_style{fg = Fg, bg = Bg, attrs = Attrs}.

%% ---------------------------------------------------------------------------
%% Optimization
%% ---------------------------------------------------------------------------

-spec optimize_operations([operation()]) -> [operation()].
optimize_operations(Ops) ->
    remove_redundant_styles(merge_adjacent_text(Ops)).

-spec merge_adjacent_text([operation()]) -> [operation()].
merge_adjacent_text(Ops) ->
    lists:reverse(lists:foldl(fun merge_text/2, [], Ops)).

-spec merge_text(operation(), [operation()]) -> [operation()].
merge_text({text, T1}, [{text, T2} | Rest]) ->
    [{text, <<T2/binary, T1/binary>>} | Rest];
merge_text(Op, Acc) ->
    [Op | Acc].

-spec remove_redundant_styles([operation()]) -> [operation()].
remove_redundant_styles(Ops) ->
    {Rev, _Last} = lists:foldl(fun filter_style/2, {[], undefined}, Ops),
    lists:reverse(Rev).

-spec filter_style(operation(), {[operation()], #dui_style{} | undefined}) ->
    {[operation()], #dui_style{} | undefined}.
filter_style({style, Style}, {Acc, Last}) ->
    case Last =/= undefined andalso educkui_style:equal(Style, Last) of
        true -> {Acc, Last};
        false -> {[{style, Style} | Acc], Style}
    end;
filter_style(Op, {Acc, Last}) ->
    {[Op | Acc], Last}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec finalize_span(span()) -> span().
finalize_span({Row, StartCol, EndCol, Cells}) ->
    {Row, StartCol, EndCol, lists:reverse(Cells)}.
