%% @doc A stateless ASCII line chart widget.
%%
%% Plots a series of values as `*' points across the widget's width, mapping
%% each sampled value into the vertical range. Props: `{values, [number()]}',
%% `{style, term()}'.
-module(educkui_widget_line_chart).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Values = maps:get(values, Props, []),
    Style = educkui_visualization_helper:style_from_prop(
        maps:get(style, Props, undefined)),
    W = Rect#dui_rect.width,
    H = Rect#dui_rect.height,
    case Values of
        [] ->
            educkui_render_node:empty();
        _ ->
            Points = educkui_visualization_helper:sample_series(Values, W),
            Min = lists:min(Points),
            Max = lists:max(Points),
            Cells = [{X, y_for(V, Min, Max, H), point_cell(Style)}
                     || {X, V} <- educkui_visualization_helper:zip_short(
                                     lists:seq(0, W - 1), Points)],
            educkui_render_node:cells(Cells)
    end.

-spec describe() -> map().
describe() ->
    #{name => <<"LineChart">>, description => <<"An ASCII line chart widget">>}.

-spec default_props() -> map().
default_props() ->
    #{values => [], style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec y_for(number(), number(), number(), non_neg_integer()) -> non_neg_integer().
y_for(V, Min, Max, H) when H > 1 ->
    case Max =:= Min of
        true -> H div 2;
        false -> max(0, min(H - 1, round((1 - (V - Min) / (Max - Min)) * (H - 1))))
    end;
y_for(_V, _Min, _Max, _H) ->
    0.

-spec point_cell(#dui_style{} | undefined) -> #dui_cell{}.
point_cell(Style) ->
    educkui_visualization_helper:apply_style(educkui_cell:new(<<"*">>), Style).
