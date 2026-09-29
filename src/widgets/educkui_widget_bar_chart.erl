%% @doc A horizontal bar chart widget.
-module(educkui_widget_bar_chart).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Values = maps:get(values, Props, []),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    FillStyle = style_from_prop(maps:get(fill_style, Props, undefined)),
    Width = Rect#dui_rect.width,
    Max = lists:max(Values ++ [1]),
    Cells = lists:flatmap(
        fun({Value, Y}) when Y < Rect#dui_rect.height ->
            Filled = max(0, min(Width, round(Value / Max * Width))),
            [{X, Y, bar_cell(X < Filled, Style, FillStyle)}
             || X <- lists:seq(0, Width - 1)];
           (_) -> []
        end,
        zip_short(Values, lists:seq(0, Rect#dui_rect.height - 1))),
    educkui_render_node:cells(Cells).

-spec describe() -> map().
describe() ->
    #{name => <<"BarChart">>, description => <<"A horizontal bar chart">>}.

-spec default_props() -> map().
default_props() ->
    #{values => [], style => undefined, fill_style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec zip_short([term()], [term()]) -> [{term(), term()}].
zip_short(A, B) ->
    zip_short(A, B, []).

-spec zip_short([term()], [term()], [{term(), term()}]) -> [{term(), term()}].
zip_short([], _B, Acc) -> lists:reverse(Acc);
zip_short(_A, [], Acc) -> lists:reverse(Acc);
zip_short([A | As], [B | Bs], Acc) -> zip_short(As, Bs, [{A, B} | Acc]).

-spec bar_cell(boolean(), #dui_style{} | undefined, #dui_style{} | undefined) ->
    #dui_cell{}.
bar_cell(true, _Style, FillStyle) ->
    apply_style(educkui_cell:new(<<"█"/utf8>>), FillStyle);
bar_cell(false, Style, _FillStyle) ->
    apply_style(educkui_cell:new(<<" ">>), Style).

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
