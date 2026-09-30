%% @doc A stateless view for styled, pre-split text lines.
%%
%% Props:
%% - `{lines, [[{binary(), style()}]]}' — each line is a list of styled spans;
%%   `style()' may be a `#dui_style{}', a style map, or `undefined'.
%% - `{style, style()}' — base style merged into every span.
%%
%% Unlike `educkui_widget_markdown_viewer', this widget performs no parsing or
%% wrapping: it simply places graphemes at their display columns, which makes it
%% suitable for syntax-highlighted JSON, protobuf dumps and log colouring where
%% the caller already knows the spans.
-module(educkui_widget_text_view).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Lines = maps:get(lines, Props, []),
    Base = style_from_prop(maps:get(style, Props, undefined)),
    Height = max(0, Rect#dui_rect.height),
    Visible = lists:sublist(Lines, Height),
    Cells = lists:flatmap(
        fun({Spans, Y}) ->
            line_cells(Spans, Y, Rect#dui_rect.width, Base)
        end,
        lists:zip(Visible, lists:seq(0, length(Visible) - 1))),
    educkui_render_node:cells(Cells).

-spec describe() -> map().
describe() ->
    #{name => <<"Text view">>, description => <<"Styled text spans">>}.

-spec default_props() -> map().
default_props() ->
    #{lines => [], style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec line_cells([{binary(), term()}],
                 integer(), non_neg_integer(), #dui_style{} | undefined) ->
    [{integer(), integer(), #dui_cell{}}].
line_cells(Spans, Y, MaxWidth, Base) ->
    {Rev, _} = lists:foldl(
        fun(_Span, {Acc, X}) when X >= MaxWidth ->
                {Acc, X};
           (Span, {Acc, X}) ->
                {Text, SpanStyle} = Span,
                Style = merge_opt(Base, style_from_prop(SpanStyle)),
                {Display, _} = educkui_display_width:truncate(Text, MaxWidth - X),
                place_graphemes(string:to_graphemes(Display), X, Y, MaxWidth,
                                Style, Acc)
        end,
        {[], 0},
        Spans),
    lists:reverse(Rev).

-spec place_graphemes([char() | [char()]], non_neg_integer(), integer(),
                      non_neg_integer(), #dui_style{} | undefined,
                      [{integer(), integer(), #dui_cell{}}]) ->
    {[{integer(), integer(), #dui_cell{}}], non_neg_integer()}.
place_graphemes([], X, _Y, _MaxWidth, _Style, Acc) ->
    {Acc, X};
place_graphemes([G | Rest], X, Y, MaxWidth, Style, Acc) ->
    Char = unicode:characters_to_binary([G]),
    {_CX, _CY, Cell} = educkui_component_helpers:positioned_cell(X, Y, Char, Style),
    Width = educkui_cell:width(Cell),
    Acc1 = case Width >= 2 andalso X + 1 < MaxWidth of
        true ->
            Placeholder = educkui_cell:wide_placeholder(Cell),
            [{X + 1, Y, Placeholder}, {X, Y, Cell} | Acc];
        false ->
            [{X, Y, Cell} | Acc]
    end,
    place_graphemes(Rest, X + Width, Y, MaxWidth, Style, Acc1).

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).

-spec merge_opt(#dui_style{} | undefined, #dui_style{} | undefined) ->
    #dui_style{} | undefined.
merge_opt(Base, undefined) -> Base;
merge_opt(undefined, Override) -> Override;
merge_opt(Base, #dui_style{} = Override) -> educkui_style:merge(Base, Override).
