-module(educkui_widget_progress_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_progress(Value, W) ->
    Node = educkui_widget_progress:render(#{value => Value},
        #dui_rect{width = W, height = 1}),
    Node#dui_node.cells.

char_n(Cells, N) ->
    {_X, _Y, Cell} = lists:nth(N, Cells),
    Cell#dui_cell.char.

half_filled_test() ->
    Cells = render_progress(0.5, 4),
    ?assertEqual(4, length(Cells)),
    ?assertEqual(<<"█"/utf8>>, char_n(Cells, 1)),
    ?assertEqual(<<"█"/utf8>>, char_n(Cells, 2)),
    ?assertEqual(<<"░"/utf8>>, char_n(Cells, 3)),
    ?assertEqual(<<"░"/utf8>>, char_n(Cells, 4)).

full_test() ->
    Cells = render_progress(1.0, 3),
    ?assertEqual(<<"█"/utf8>>, char_n(Cells, 3)).

empty_test() ->
    Cells = render_progress(0.0, 3),
    ?assertEqual(<<"░"/utf8>>, char_n(Cells, 1)).
