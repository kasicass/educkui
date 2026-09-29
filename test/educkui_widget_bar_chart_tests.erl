-module(educkui_widget_bar_chart_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_bars(Values, W, H) ->
    Node = educkui_widget_bar_chart:render(#{values => Values},
        #dui_rect{width = W, height = H}),
    Node#dui_node.cells.

char_at(Cells, X, Y) ->
    {value, {_X, _Y, Cell}} = lists:search(
        fun({Cx, Cy, _}) -> Cx =:= X andalso Cy =:= Y end, Cells),
    Cell#dui_cell.char.

full_bar_test() ->
    Cells = render_bars([10], 5, 1),
    ?assertEqual(<<"█"/utf8>>, char_at(Cells, 4, 0)).

half_bar_test() ->
    Cells = render_bars([5, 10], 4, 2),
    ?assertEqual(<<"█"/utf8>>, char_at(Cells, 1, 0)),
    ?assertEqual(<<" ">>, char_at(Cells, 3, 0)),
    ?assertEqual(<<"█"/utf8>>, char_at(Cells, 3, 1)).

empty_test() ->
    Cells = render_bars([], 4, 2),
    ?assertEqual([], Cells).
