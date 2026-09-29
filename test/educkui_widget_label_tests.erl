-module(educkui_widget_label_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_label(Props, W) ->
    Node = educkui_widget_label:render(Props, #dui_rect{width = W, height = 1}),
    Node#dui_node.cells.

char_n(Cells, N) ->
    {_X, _Y, Cell} = lists:nth(N, Cells),
    Cell#dui_cell.char.

left_align_test() ->
    Cells = render_label(#{text => <<"Hi">>}, 5),
    ?assertEqual(5, length(Cells)),
    ?assertEqual(<<"H">>, char_n(Cells, 1)),
    ?assertEqual(<<" ">>, char_n(Cells, 5)).

right_align_test() ->
    Cells = render_label(#{text => <<"Hi">>, align => right}, 5),
    ?assertEqual(<<" ">>, char_n(Cells, 1)),
    ?assertEqual(<<"H">>, char_n(Cells, 4)),
    ?assertEqual(<<"i">>, char_n(Cells, 5)).

center_align_test() ->
    Cells = render_label(#{text => <<"Hi">>, align => center}, 5),
    ?assertEqual(<<"H">>, char_n(Cells, 2)),
    ?assertEqual(<<"i">>, char_n(Cells, 3)).

truncate_test() ->
    Cells = render_label(#{text => <<"Hello">>, truncate => true}, 3),
    ?assertEqual(3, length(Cells)),
    ?assertEqual(<<"H">>, char_n(Cells, 1)),
    ?assertEqual(<<"e">>, char_n(Cells, 2)),
    ?assertEqual(<<"l">>, char_n(Cells, 3)).

truncate_ellipsis_test() ->
    Cells = render_label(#{text => <<"Hello">>, truncate => true}, 4),
    ?assertEqual(4, length(Cells)),
    ?assertEqual(<<"H">>, char_n(Cells, 1)),
    ?assertEqual(<<"e">>, char_n(Cells, 2)),
    ?assertEqual(<<"l">>, char_n(Cells, 3)),
    ?assertEqual(<<"…"/utf8>>, char_n(Cells, 4)).

style_test() ->
    Cells = render_label(#{text => <<"A">>, style => #{fg => red}}, 1),
    {_X, _Y, Cell} = hd(Cells),
    ?assertEqual(red, Cell#dui_cell.fg).
