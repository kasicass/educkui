-module(educkui_widget_gauge_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_gauge(Value, W) ->
    Node = educkui_widget_gauge:render(#{value => Value},
        #dui_rect{width = W, height = 1}),
    Node#dui_node.cells.

char_n(Cells, N) ->
    {_X, _Y, Cell} = lists:nth(N, Cells),
    Cell#dui_cell.char.

half_test() ->
    Cells = render_gauge(0.5, 4),
    ?assertEqual(<<"█"/utf8>>, char_n(Cells, 1)),
    ?assertEqual(<<"█"/utf8>>, char_n(Cells, 2)),
    ?assertEqual(<<"░"/utf8>>, char_n(Cells, 4)).

label_test() ->
    Cells = render_gauge(1.0, 2),
    %% bar cells at 0,1; label "100%" starts at W+1 = 3.
    ?assertEqual(<<"1">>, char_n(Cells, 3)).
