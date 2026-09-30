%% @doc A table widget rendering rows of columns with optional fixed column
%% widths, alignment, per-column styles and row selection.
%%
%% Props:
%% - `{header, [binary()]}'          optional header row (rendered at Y = 0)
%% - `{rows, [[binary()]]}'          body rows
%% - `{widths, [non_neg_integer()]}' optional fixed column widths. When
%%   omitted, each row is joined with a single space (legacy behaviour).
%% - `{align, left | center | right | [left | center | right]}'  column
%%   alignment (single value or one per column)
%% - `{selected, non_neg_integer()}' body-row index to highlight (0-based)
%% - `{selected_style, style()}'     style merged onto the selected row
%% - `{column_styles, [style()]}'    per-column styles merged onto the row
%% - `{style, style()}'              base row style
%% - `{header_style, style()}'       header style
%%
%% The widget renders at most `Rect.height' rows; the caller is expected to
%% window the rows itself (see `educkui_widget_list:visible_range/4').
-module(educkui_widget_table).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Rows = maps:get(rows, Props, []),
    Header = maps:get(header, Props, undefined),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    HeaderStyle = style_from_prop(maps:get(header_style, Props, undefined)),
    Widths = maps:get(widths, Props, undefined),
    Align = maps:get(align, Props, left),
    Selected = maps:get(selected, Props, undefined),
    SelectedStyle = style_from_prop(maps:get(selected_style, Props, undefined)),
    ColumnStyles = [style_from_prop(S) || S <- maps:get(column_styles, Props, [])],
    Width = Rect#dui_rect.width,
    Height = Rect#dui_rect.height,

    HeaderCells = case Header =/= undefined andalso Height > 0 of
        true ->
            row_cells(Header, 0, Width, Widths, Align, HeaderStyle, ColumnStyles);
        false ->
            []
    end,

    HeaderOffset = case HeaderCells of
        [] -> 0;
        _ -> 1
    end,
    Visible = lists:sublist(Rows, max(0, Height - HeaderOffset)),
    BodyCells = lists:flatmap(
        fun({Row, Index}) ->
            Y = HeaderOffset + Index,
            RowStyle = case Selected of
                Index -> merge_opt(Style, SelectedStyle);
                _ -> Style
            end,
            row_cells(Row, Y, Width, Widths, Align, RowStyle, ColumnStyles)
        end,
        lists:zip(Visible, lists:seq(0, length(Visible) - 1))),

    educkui_render_node:cells(HeaderCells ++ BodyCells).

-spec describe() -> map().
describe() ->
    #{name => <<"Table">>, description => <<"A table widget with selection">>}.

-spec default_props() -> map().
default_props() ->
    #{rows => [], header => undefined, widths => undefined, align => left,
      selected => undefined, style => undefined, header_style => undefined,
      selected_style => undefined, column_styles => []}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec row_cells([binary()], integer(), non_neg_integer(),
                [non_neg_integer()] | undefined,
                term(), #dui_style{} | undefined, [#dui_style{} | undefined]) ->
    [{integer(), integer(), #dui_cell{}}].
row_cells(Row, Y, Width, undefined, _Align, Style, _ColStyles) ->
    %% Legacy: join columns with a space and truncate to the available width.
    text_cells(join_binary(Row, <<" ">>), 0, Y, Width, Style);
row_cells(Row, Y, Width, Widths, Align, Style, ColStyles) ->
    Padded = pad_row(Row, length(Widths)),
    Aligns = aligns(Align, length(Widths)),
    Styles = pad_styles(ColStyles, length(Widths)),
    {CellGroups, _} = lists:foldl(
        fun({Value, W, A, ColStyle}, {Acc, X}) ->
            Display = fit(Value, W, A),
            ColStyle1 = merge_opt(Style, ColStyle),
            {[text_cells(Display, X, Y, W, ColStyle1) | Acc], X + W}
        end,
        {[], 0},
        zip4(Padded, Widths, Aligns, Styles)),
    [Cell || Cell <- lists:append(lists:reverse(CellGroups)),
             element(1, Cell) < Width].

-spec text_cells(binary(), non_neg_integer(), integer(), non_neg_integer(),
                 #dui_style{} | undefined) ->
    [{non_neg_integer(), integer(), #dui_cell{}}].
text_cells(Text, X0, Y, MaxWidth, Style) ->
    {Display, _Used} = educkui_display_width:truncate(Text, MaxWidth),
    Graphemes = string:to_graphemes(Display),
    {Rev, _} = lists:foldl(
        fun(G, {Acc, CurX}) ->
            Char = unicode:characters_to_binary([G]),
            {_CX, _CY, Cell} = educkui_component_helpers:positioned_cell(CurX, Y, Char, Style),
            Width = educkui_cell:width(Cell),
            NewAcc = case Width >= 2 andalso CurX + 1 < X0 + MaxWidth of
                true ->
                    Placeholder = educkui_cell:wide_placeholder(Cell),
                    [{CurX + 1, Y, Placeholder}, {CurX, Y, Cell} | Acc];
                false ->
                    [{CurX, Y, Cell} | Acc]
            end,
            {NewAcc, CurX + Width}
        end,
        {[], X0},
        Graphemes),
    lists:reverse(Rev).

%% @doc Fits `Value' into exactly `W' display columns with the given alignment.
-spec fit(binary(), non_neg_integer(), left | center | right) -> binary().
fit(_Value, W, _Align) when W =< 0 ->
    <<>>;
fit(Value, W, Align) ->
    {Truncated, Used} = educkui_display_width:truncate(Value, W),
    Pad = max(0, W - Used),
    case Align of
        left -> <<Truncated/binary, (spaces(Pad))/binary>>;
        right -> <<(spaces(Pad))/binary, Truncated/binary>>;
        center ->
            Left = Pad div 2,
            Right = Pad - Left,
            <<(spaces(Left))/binary, Truncated/binary, (spaces(Right))/binary>>
    end.

-spec spaces(non_neg_integer()) -> binary().
spaces(0) -> <<>>;
spaces(N) when N > 0 -> binary:copy(<<" ">>, N).

-spec pad_row([binary()], non_neg_integer()) -> [binary()].
pad_row(Row, N) ->
    L = length(Row),
    case L >= N of
        true -> lists:sublist(Row, N);
        false -> Row ++ lists:duplicate(N - L, <<>>)
    end.

-spec aligns(term(), non_neg_integer()) -> [left | center | right].
aligns(Align, N) when Align =:= left; Align =:= center; Align =:= right ->
    lists:duplicate(N, Align);
aligns(Aligns, N) when is_list(Aligns) ->
    pad_styles(Aligns, N).

-spec pad_styles([term()], non_neg_integer()) -> [term()].
pad_styles(Styles, N) ->
    L = length(Styles),
    case L >= N of
        true -> lists:sublist(Styles, N);
        false -> Styles ++ lists:duplicate(N - L, undefined)
    end.

-spec zip4([A], [B], [C], [D]) -> [{A, B, C, D}].
zip4([A | As], [B | Bs], [C | Cs], [D | Ds]) ->
    [{A, B, C, D} | zip4(As, Bs, Cs, Ds)];
zip4([], [], [], []) ->
    [].

-spec join_binary([binary()], binary()) -> binary().
join_binary([], _Sep) -> <<>>;
join_binary([H], _Sep) -> H;
join_binary([H | T], Sep) -> <<H/binary, Sep/binary, (join_binary(T, Sep))/binary>>.

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).

-spec merge_opt(#dui_style{} | undefined, #dui_style{} | undefined) ->
    #dui_style{} | undefined.
merge_opt(Base, undefined) -> Base;
merge_opt(undefined, Override) -> Override;
merge_opt(Base, #dui_style{} = Override) -> educkui_style:merge(Base, Override).
