-module(educkui_widget_scroll_bar_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_bar(Props, W, H) ->
    Node = educkui_widget_scroll_bar:render(Props, #dui_rect{width = W, height = H}),
    Node#dui_node.cells.

char_n(Cells, N) ->
    {_X, _Y, Cell} = lists:nth(N, Cells),
    Cell#dui_cell.char.

vertical_full_viewport_test() ->
    %% viewport == total -> thumb fills the whole bar.
    Cells = render_bar(#{total => 10, offset => 0, viewport => 10}, 1, 5),
    ?assertEqual(5, length(Cells)),
    ?assertEqual(<<"█"/utf8>>, char_n(Cells, 1)),
    ?assertEqual(<<"█"/utf8>>, char_n(Cells, 5)).

vertical_partial_test() ->
    Cells = render_bar(#{total => 10, offset => 0, viewport => 2}, 1, 5),
    %% Thumb size = 1; at offset 0 it is at the top.
    ?assertEqual(<<"█"/utf8>>, char_n(Cells, 1)),
    ?assertEqual(<<"│"/utf8>>, char_n(Cells, 5)).

horizontal_test() ->
    Cells = render_bar(#{total => 10, offset => 5, viewport => 2, vertical => false}, 5, 1),
    ?assertEqual(5, length(Cells)),
    ?assertEqual(<<"█"/utf8>>, char_n(Cells, 4)).
