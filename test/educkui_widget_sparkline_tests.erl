-module(educkui_widget_sparkline_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_sparkline(Values, W) ->
    Node = educkui_widget_sparkline:render(#{values => Values},
        #dui_rect{width = W, height = 1}),
    Node#dui_node.cells.

count_cells_test() ->
    Cells = render_sparkline([1, 2, 3, 4], 4),
    ?assertEqual(4, length(Cells)).

short_series_test() ->
    Cells = render_sparkline([5, 5], 4),
    ?assertEqual(2, length(Cells)).

empty_series_test() ->
    Cells = render_sparkline([], 4),
    ?assertEqual([], Cells).

style_test() ->
    Cells = render_sparkline([1, 2, 3], 3),
    {_X, _Y, Cell} = hd(Cells),
    ?assert(lists:member(Cell#dui_cell.char,
        [<<"▁"/utf8>>, <<"▂"/utf8>>, <<"▃"/utf8>>, <<"▄"/utf8>>,
         <<"▅"/utf8>>, <<"▆"/utf8>>, <<"▇"/utf8>>, <<"█"/utf8>>])).
