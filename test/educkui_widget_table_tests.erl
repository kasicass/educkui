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

widths_test() ->
    Cells = render_table(#{
        header => [<<"A">>, <<"B">>],
        widths => [3, 2],
        rows => [[<<"x">>, <<"y">>]]
    }),
    ?assertEqual(<<"A">>, char_at(Cells, 0, 0)),
    ?assertEqual(<<"B">>, char_at(Cells, 3, 0)),
    ?assertEqual(<<"x">>, char_at(Cells, 0, 1)),
    ?assertEqual(<<"y">>, char_at(Cells, 3, 1)).

right_align_test() ->
    Cells = render_table(#{
        widths => [3],
        align => right,
        rows => [[<<"x">>]]
    }),
    ?assertEqual(<<" ">>, char_at(Cells, 0, 0)),
    ?assertEqual(<<"x">>, char_at(Cells, 2, 0)).

center_align_test() ->
    Cells = render_table(#{
        widths => [4],
        align => center,
        rows => [[<<"x">>]]
    }),
    ?assertEqual(<<"x">>, char_at(Cells, 1, 0)).

selected_style_test() ->
    Cells = render_table(#{
        rows => [[<<"a">>], [<<"b">>]],
        selected => 1,
        selected_style => #{fg => red}
    }),
    ?assertEqual(red, fg_at(Cells, 0, 1)),
    ?assertNotEqual(red, fg_at(Cells, 0, 0)).

column_styles_test() ->
    Cells = render_table(#{
        widths => [2, 2],
        rows => [[<<"a">>, <<"b">>]],
        column_styles => [#{fg => red}, #{fg => green}]
    }),
    ?assertEqual(red, fg_at(Cells, 0, 0)),
    ?assertEqual(green, fg_at(Cells, 2, 0)).

fg_at(Cells, X, Y) ->
    {value, {_X, _Y, Cell}} = lists:search(
        fun({Cx, Cy, _}) -> Cx =:= X andalso Cy =:= Y end, Cells),
    Cell#dui_cell.fg.
