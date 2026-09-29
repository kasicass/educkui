-module(educkui_widget_canvas_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_canvas(Pixels) ->
    Node = educkui_widget_canvas:render(#{pixels => Pixels},
        #dui_rect{width = 10, height = 10}),
    Node#dui_node.cells.

pixels_test() ->
    Cells = render_canvas([{1, 2, <<"x">>}, {3, 4, <<"y">>}]),
    ?assertEqual(2, length(Cells)),
    {1, 2, C1} = hd(Cells),
    ?assertEqual(<<"x">>, C1#dui_cell.char).

empty_test() ->
    Cells = render_canvas([]),
    ?assertEqual([], Cells).
