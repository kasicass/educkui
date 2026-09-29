-module(educkui_widget_block_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_block(Props, W, H) ->
    Node = educkui_widget_block:render(Props, #dui_rect{width = W, height = H}),
    Node#dui_node.cells.

border_test() ->
    Cells = render_block(#{border => true}, 4, 3),
    ?assertEqual(<<"┌"/utf8>>, cell_at(Cells, 0, 0)),
    ?assertEqual(<<"┐"/utf8>>, cell_at(Cells, 3, 0)),
    ?assertEqual(<<"└"/utf8>>, cell_at(Cells, 0, 2)),
    ?assertEqual(<<"┘"/utf8>>, cell_at(Cells, 3, 2)).

background_fill_test() ->
    Cells = render_block(#{style => #{bg => blue}}, 2, 2),
    ?assertEqual(4, length(Cells)),
    ?assertEqual(blue, bg_at(Cells, 0, 0)).

cell_at(Cells, X, Y) ->
    {value, {_X, _Y, Cell}} = lists:search(fun({Cx, Cy, _}) -> Cx =:= X andalso Cy =:= Y end, Cells),
    Cell#dui_cell.char.

bg_at(Cells, X, Y) ->
    {value, {_X, _Y, Cell}} = lists:search(fun({Cx, Cy, _}) -> Cx =:= X andalso Cy =:= Y end, Cells),
    Cell#dui_cell.bg.
