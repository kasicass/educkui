%% @doc Charts showcase: gauge, sparkline, line chart and bar chart.
-module(dui_charts).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) -> #{}.

event_to_msg(#dui_event{type = key, key = esc}, _State) -> {msg, quit};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) -> {State, [educkui_command:quit()]};
update(_Msg, State) -> {State, []}.

view(_State) ->
    educkui_render_node:stack(vertical, [
        title(<<"Charts - Esc to quit">>),
        label(<<"Gauge:">>),
        sized(educkui_widget_gauge, #{value => 0.6}, 30, 1),
        label(<<"Sparkline:">>),
        sized(educkui_widget_sparkline,
              #{values => [1, 2, 3, 5, 4, 6, 5, 3, 2, 1]}, 30, 1),
        label(<<"Line chart:">>),
        sized(educkui_widget_line_chart,
              #{values => [1, 2, 3, 5, 4, 6, 5, 3, 2, 1]}, 30, 6),
        label(<<"Bar chart:">>),
        sized(educkui_widget_bar_chart,
              #{values => [2, 4, 6, 8, 6, 4, 2]}, 30, 7)
    ]).

title(Text) ->
    educkui_render_node:text(Text, educkui_style:from([{fg, cyan}, {bold, true}])).

label(Text) ->
    educkui_render_node:text(Text).

sized(Module, Props, W, H) ->
    educkui_render_node:height(
        educkui_render_node:width(
            educkui_render_node:widget(Module, Props), W),
        H).
