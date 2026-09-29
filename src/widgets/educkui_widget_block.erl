%% @doc A rectangular block with optional background fill and border.
-module(educkui_widget_block).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Border = maps:get(border, Props, false),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    BorderStyle = style_from_prop(maps:get(border_style, Props, undefined)),

    Background = fill_background(Style, Rect),
    BorderCells = case Border of
        true -> draw_border(Rect, BorderStyle);
        false -> []
    end,
    educkui_render_node:cells(Background ++ BorderCells).

-spec describe() -> map().
describe() ->
    #{name => <<"Block">>, description => <<"A rectangular block widget">>}.

-spec default_props() -> map().
default_props() ->
    #{border => false, style => undefined, border_style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec fill_background(#dui_style{} | undefined, #dui_rect{}) ->
    [{integer(), integer(), #dui_cell{}}].
fill_background(#dui_style{bg = Bg}, #dui_rect{width = W, height = H})
        when Bg =/= undefined, Bg =/= default ->
    Cell = educkui_cell:new(<<" ">>, [{bg, Bg}]),
    [{X, Y, Cell} || Y <- lists:seq(0, H - 1), X <- lists:seq(0, W - 1)];
fill_background(_Style, _Rect) ->
    [].

-spec draw_border(#dui_rect{}, #dui_style{} | undefined) ->
    [{integer(), integer(), #dui_cell{}}].
draw_border(#dui_rect{width = W, height = H}, Style) when W >= 2, H >= 2 ->
    TopLeft = {0, 0, border_cell(<<"┌"/utf8>>, Style)},
    TopRight = {W - 1, 0, border_cell(<<"┐"/utf8>>, Style)},
    BottomLeft = {0, H - 1, border_cell(<<"└"/utf8>>, Style)},
    BottomRight = {W - 1, H - 1, border_cell(<<"┘"/utf8>>, Style)},
    Top = [{X, 0, border_cell(<<"─"/utf8>>, Style)} || X <- lists:seq(1, W - 2)],
    Bottom = [{X, H - 1, border_cell(<<"─"/utf8>>, Style)} || X <- lists:seq(1, W - 2)],
    Left = [{0, Y, border_cell(<<"│"/utf8>>, Style)} || Y <- lists:seq(1, H - 2)],
    Right = [{W - 1, Y, border_cell(<<"│"/utf8>>, Style)} || Y <- lists:seq(1, H - 2)],
    [TopLeft, TopRight, BottomLeft, BottomRight] ++ Top ++ Bottom ++ Left ++ Right;
draw_border(_Rect, _Style) ->
    [].

-spec border_cell(binary(), #dui_style{} | undefined) -> #dui_cell{}.
border_cell(Char, Style) ->
    Cell0 = educkui_cell:new(Char),
    case Style of
        undefined -> Cell0;
        #dui_style{fg = Fg, bg = Bg, attrs = Attrs} ->
            C1 = case Fg of
                undefined -> Cell0;
                _ -> educkui_cell:put_fg(Cell0, Fg)
            end,
            C2 = case Bg of
                undefined -> C1;
                _ -> educkui_cell:put_bg(C1, Bg)
            end,
            lists:foldl(fun(A, C) -> educkui_cell:add_attr(C, A) end, C2, Attrs)
    end.

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).
