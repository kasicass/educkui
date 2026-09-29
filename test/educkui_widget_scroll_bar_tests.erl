-module(educkui_widget_scroll_bar_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_bar(Props, W, H) ->
    Node = educkui_widget_scroll_bar:render(Props, #dui_rect{width = W, height = H}),
    Node#dui_node.cells.

vertical_full_viewport_test() ->
    %% viewport == total -> thumb fills the whole bar.
    Cells = render_bar(#{total => 10, offset => 0, viewport => 10}, 1, 5),
    ?assertEqual(5, length(Cells)),
    ?assertEqual(<<"█"/utf8>>, (lists:nth(1, Cells))#dui_cell.char),
    ?assertEqual(<<"█"/utf8>>, (lists:nth(5, Cells))#dui_cell.char).

vertical_partial_test() ->
    Cells = render_bar(#{total => 10, offset => 0, viewport => 2}, 1, 5),
    %% Thumb size = 1; at offset 0 it is at the top.
    ?assertEqual(<<"█"/utf8>>, (lists:nth(1, Cells))#dui_cell.char),
    ?assertEqual(<<"│"/utf8>>, (lists:nth(5, Cells))#dui_cell.char).

horizontal_test() ->
    Cells = render_bar(#{total => 10, offset => 5, viewport => 2, vertical => false}, 5, 1),
    ?assertEqual(5, length(Cells)),
    ?assertEqual(<<"█"/utf8>>, (lists:nth(3, Cells))#dui_cell.char).
