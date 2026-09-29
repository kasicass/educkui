-module(educkui_widget_table_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_table(Props) ->
    Node = educkui_widget_table:render(Props, #dui_rect{width = 10, height = 3}),
    Node#dui_node.cells.

char_at(Cells, X, Y) ->
    {value, {_X, _Y, Cell}} = lists:search(
        fun({Cx, Cy, _}) -> Cx =:= X andalso Cy =:= Y end, Cells),
    Cell#dui_cell.char.

header_and_rows_test() ->
    Cells = render_table(#{
        header => [<<"Name">>, <<"Age">>],
        rows => [[<<"Alice">>, <<"30">>], [<<"Bob">>, <<"25">>]]
    }),
    ?assertEqual(<<"N">>, char_at(Cells, 0, 0)),
    ?assertEqual(<<"A">>, char_at(Cells, 0, 1)),
    ?assertEqual(<<"B">>, char_at(Cells, 0, 2)).

header_style_test() ->
    Cells = render_table(#{
        header => [<<"H">>],
        header_style => #{fg => red}
    }),
    {value, {_X, _Y, Cell}} = lists:search(fun({Cx, Cy, _}) -> Cx =:= 0 andalso Cy =:= 0 end, Cells),
    ?assertEqual(red, Cell#dui_cell.fg).
