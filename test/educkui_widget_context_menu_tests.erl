-module(educkui_widget_context_menu_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_menu(Props) ->
    Node = educkui_widget_context_menu:render(Props, #dui_rect{width = 20, height = 10}),
    Node#dui_node.cells.

char_at(Cells, X, Y) ->
    Matches = [{Cx, Cy, Cell} || {Cx, Cy, Cell} <- Cells, Cx =:= X, Cy =:= Y],
    {_X, _Y, Cell} = lists:last(Matches),
    Cell#dui_cell.char.

border_and_items_test() ->
    Cells = render_menu(#{items => [<<"Copy">>, <<"Cut">>], x => 2, y => 2}),
    ?assertEqual(<<"┌"/utf8>>, char_at(Cells, 2, 2)),
    ?assertEqual(<<"C">>, char_at(Cells, 4, 3)),
    ?assertEqual(<<"C">>, char_at(Cells, 4, 4)).

selected_highlight_test() ->
    Cells = render_menu(#{items => [<<"Copy">>, <<"Cut">>], selected => 1,
                          x => 2, y => 2}),
    {value, {_X, _Y, Cell}} = lists:search(
        fun({Cx, Cy, _C}) -> Cx =:= 4 andalso Cy =:= 4 end, Cells),
    ?assert(educkui_cell:has_attr(Cell, reverse)).
