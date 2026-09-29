%% @doc A sparkline widget rendering a value series as block characters.
-module(educkui_widget_sparkline).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-define(BLOCKS, [
    <<"▁"/utf8>>, <<"▂"/utf8>>, <<"▃"/utf8>>, <<"▄"/utf8>>,
    <<"▅"/utf8>>, <<"▆"/utf8>>, <<"▇"/utf8>>, <<"█"/utf8>>
]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Values = maps:get(values, Props, []),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    Width = Rect#dui_rect.width,
    Normalized = normalize(Values, Width),
    Cells = case Normalized of
        [] -> [];
        _ ->
            Min = lists:min(Normalized),
            Max = lists:max(Normalized),
            [{X, 0, spark_cell(V, Min, Max, Style)}
             || {X, V} <- lists:zip(lists:seq(0, length(Normalized) - 1), Normalized)]
    end,
    educkui_render_node:cells(Cells).

-spec describe() -> map().
describe() ->
    #{name => <<"Sparkline">>, description => <<"A compact inline trend graph">>}.

-spec default_props() -> map().
default_props() ->
    #{values => [], style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec normalize([number()], non_neg_integer()) -> [number()].
normalize([], _Width) -> [];
normalize(_Values, 0) -> [];
normalize(Values, Width) when length(Values) =< Width ->
    Values;
normalize(Values, Width) ->
    %% Sample evenly across the series.
    Len = length(Values),
    [lists:nth(max(1, round(I * Len / Width)), Values) || I <- lists:seq(1, Width)].

-spec spark_cell(number(), number(), number(), #dui_style{} | undefined) -> #dui_cell{}.
spark_cell(Value, Min, Max, Style) ->
    Level = block_level(Value, Min, Max),
    Char = lists:nth(Level, ?BLOCKS),
    Cell0 = educkui_cell:new(Char),
    apply_style(Cell0, Style).

-spec block_level(number(), number(), number()) -> 1..8.
block_level(Value, Min, Max) ->
    case Max =:= Min of
        true -> 4;
        false ->
            Ratio = (Value - Min) / (Max - Min),
            min(8, max(1, round(Ratio * 7) + 1))
    end.

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
