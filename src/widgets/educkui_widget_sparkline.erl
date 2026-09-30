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
    Style = educkui_visualization_helper:style_from_prop(
        maps:get(style, Props, undefined)),
    Width = Rect#dui_rect.width,
    Normalized = educkui_visualization_helper:sample_series(Values, Width),
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

-spec spark_cell(number(), number(), number(), #dui_style{} | undefined) -> #dui_cell{}.
spark_cell(Value, Min, Max, Style) ->
    Level = block_level(Value, Min, Max),
    Char = lists:nth(Level, ?BLOCKS),
    Cell0 = educkui_cell:new(Char),
    educkui_visualization_helper:apply_style(Cell0, Style).

-spec block_level(number(), number(), number()) -> 1..8.
block_level(Value, Min, Max) ->
    case Max =:= Min of
        true -> 4;
        false ->
            Ratio = (Value - Min) / (Max - Min),
            min(8, max(1, round(Ratio * 7) + 1))
    end.


