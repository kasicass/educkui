-module(educkui_widget_line_chart_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_chart(Values, W, H) ->
    Node = educkui_widget_line_chart:render(#{values => Values},
        #dui_rect{width = W, height = H}),
    Node#dui_node.cells.

count_test() ->
    Cells = render_chart([1, 2, 3, 4], 4, 5),
    ?assertEqual(4, length(Cells)).

empty_test() ->
    Node = educkui_widget_line_chart:render(#{values => []},
        #dui_rect{width = 4, height = 5}),
    ?assertEqual(empty, Node#dui_node.type).

style_test() ->
    Cells = render_chart([1, 2, 3], 3, 3),
    {_X, _Y, Cell} = hd(Cells),
    ?assertEqual(<<"*">>, Cell#dui_cell.char).
