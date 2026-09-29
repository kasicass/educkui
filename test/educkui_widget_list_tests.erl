-module(educkui_widget_list_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_list(Props) ->
    Node = educkui_widget_list:render(Props, #dui_rect{width = 5, height = 2}),
    Node#dui_node.cells.

items_rendered_test() ->
    Cells = render_list(#{items => [<<"one">>, <<"two">>], selected => 0}),
    ?assertEqual(<<"o">>, char_at(Cells, 0, 0)),
    ?assertEqual(<<"t">>, char_at(Cells, 0, 1)).

selected_style_test() ->
    Cells = render_list(#{items => [<<"one">>, <<"two">>], selected => 1,
                          selected_style => #{fg => red}}),
    ?assertEqual(red, fg_at(Cells, 0, 1)).

char_at(Cells, X, Y) ->
    Cell = cell_at(Cells, X, Y),
    Cell#dui_cell.char.

cell_at(Cells, X, Y) ->
    {value, {_X, _Y, Cell}} = lists:search(
        fun({Cx, Cy, _}) -> Cx =:= X andalso Cy =:= Y end, Cells),
    Cell.

fg_at(Cells, X, Y) ->
    Cell = cell_at(Cells, X, Y),
    Cell#dui_cell.fg.
