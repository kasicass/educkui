%% @doc A progress bar widget.
-module(educkui_widget_progress).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Value = maps:get(value, Props, 0.0),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    FillStyle = style_from_prop(maps:get(fill_style, Props, undefined)),
    Width = Rect#dui_rect.width,
    Filled = clamp_filled(round(Value * Width), Width),

    Cells = [
        {X, 0, filled_cell(X < Filled, Style, FillStyle)}
        || X <- lists:seq(0, Width - 1)
    ],
    educkui_render_node:cells(Cells).

-spec describe() -> map().
describe() ->
    #{name => <<"Progress">>, description => <<"A progress bar widget">>}.

-spec default_props() -> map().
default_props() ->
    #{value => 0.0, style => undefined, fill_style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec filled_cell(boolean(), #dui_style{} | undefined, #dui_style{} | undefined) ->
    #dui_cell{}.
filled_cell(true, _Style, FillStyle) ->
    apply_style(educkui_cell:new(<<"█"/utf8>>), FillStyle);
filled_cell(false, Style, _FillStyle) ->
    apply_style(educkui_cell:new(<<"░"/utf8>>), Style).

-spec clamp_filled(integer(), non_neg_integer()) -> non_neg_integer().
clamp_filled(Filled, _Width) when Filled < 0 -> 0;
clamp_filled(Filled, Width) when Filled > Width -> Width;
clamp_filled(Filled, _Width) -> Filled.

-spec apply_style(#dui_cell{}, #dui_style{} | undefined) -> #dui_cell{}.
apply_style(Cell, undefined) -> Cell;
apply_style(Cell, #dui_style{fg = Fg, bg = Bg, attrs = Attrs}) ->
    C1 = case Fg of
        undefined -> Cell;
        _ -> educkui_cell:put_fg(Cell, Fg)
    end,
    C2 = case Bg of
        undefined -> C1;
        _ -> educkui_cell:put_bg(C1, Bg)
    end,
    lists:foldl(fun(A, C) -> educkui_cell:add_attr(C, A) end, C2, Attrs).

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).
