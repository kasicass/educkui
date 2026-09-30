%% @doc A horizontal bar chart widget.
-module(educkui_widget_bar_chart).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Values = maps:get(values, Props, []),
    Style = educkui_visualization_helper:style_from_prop(
        maps:get(style, Props, undefined)),
    FillStyle = educkui_visualization_helper:style_from_prop(
        maps:get(fill_style, Props, undefined)),
    Width = Rect#dui_rect.width,
    Max = lists:max(Values ++ [1]),
    Cells = lists:flatmap(
        fun({Value, Y}) when Y < Rect#dui_rect.height ->
            Filled = max(0, min(Width, round(Value / Max * Width))),
            [{X, Y, bar_cell(X < Filled, Style, FillStyle)}
             || X <- lists:seq(0, Width - 1)];
           (_) -> []
        end,
        educkui_visualization_helper:zip_short(
            Values, lists:seq(0, Rect#dui_rect.height - 1))),
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

-spec bar_cell(boolean(), #dui_style{} | undefined, #dui_style{} | undefined) ->
    #dui_cell{}.
bar_cell(true, _Style, FillStyle) ->
    educkui_visualization_helper:apply_style(educkui_cell:new(<<"█"/utf8>>), FillStyle);
bar_cell(false, Style, _FillStyle) ->
    educkui_visualization_helper:apply_style(educkui_cell:new(<<" ">>), Style).
