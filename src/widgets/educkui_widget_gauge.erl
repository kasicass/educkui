%% @doc A stateless gauge widget (progress bar with percentage label).
%%
%% Props: `{value, float()}' (0.0..1.0), `{style, term()}', `{fill_style, term()}'.
-module(educkui_widget_gauge).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Value = maps:get(value, Props, 0.0),
    Style = educkui_visualization_helper:style_from_prop(maps:get(style, Props, undefined)),
    FillStyle = educkui_visualization_helper:style_from_prop(
        maps:get(fill_style, Props, undefined)),
    W = Rect#dui_rect.width,
    Filled = educkui_visualization_helper:clamp(round(Value * W), 0, W),
    BarCells = [{X, 0, bar_cell(X < Filled, Style, FillStyle)}
                || X <- lists:seq(0, W - 1)],
    Percent = integer_to_list(round(Value * 100)) ++ "%",
    LabelCells = [{W + 1 + I, 0, label_cell(G)}
                  || {I, G} <- educkui_visualization_helper:zip_short(
                                   lists:seq(0, length(Percent) - 1),
                                   string:to_graphemes(Percent))],
    educkui_render_node:cells(BarCells ++ LabelCells).

-spec describe() -> map().
describe() ->
    #{name => <<"Gauge">>, description => <<"A gauge widget">>}.

-spec default_props() -> map().
default_props() ->
    #{value => 0.0, style => undefined, fill_style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec bar_cell(boolean(), #dui_style{} | undefined, #dui_style{} | undefined) ->
    #dui_cell{}.
bar_cell(true, _Style, FillStyle) ->
    educkui_visualization_helper:apply_style(educkui_cell:new(<<"█"/utf8>>), FillStyle);
bar_cell(false, Style, _FillStyle) ->
    educkui_visualization_helper:apply_style(educkui_cell:new(<<"░"/utf8>>), Style).

-spec label_cell(char() | [char()]) -> #dui_cell{}.
label_cell(G) ->
    educkui_cell:new(unicode:characters_to_binary([G])).


