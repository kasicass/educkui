-module(educkui_widget_text_view_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_view(Props) ->
    Node = educkui_widget_text_view:render(Props, #dui_rect{width = 10, height = 3}),
    Node#dui_node.cells.

cell_at(Cells, X, Y) ->
    {value, {_X, _Y, Cell}} = lists:search(
        fun({Cx, Cy, _}) -> Cx =:= X andalso Cy =:= Y end, Cells),
    Cell.

char_at(Cells, X, Y) ->
    (cell_at(Cells, X, Y))#dui_cell.char.

spans_test() ->
    Cells = render_view(#{lines => [[{<<"ab">>, undefined}, {<<"c">>, #{fg => red}}]]}),
    ?assertEqual(<<"a">>, char_at(Cells, 0, 0)),
    ?assertEqual(<<"b">>, char_at(Cells, 1, 0)),
    ?assertEqual(<<"c">>, char_at(Cells, 2, 0)),
    ?assertEqual(red, (cell_at(Cells, 2, 0))#dui_cell.fg).

multiple_lines_test() ->
    Cells = render_view(#{lines => [
        [{<<"one">>, undefined}],
        [{<<"two">>, undefined}]
    ]}),
    ?assertEqual(<<"o">>, char_at(Cells, 0, 0)),
    ?assertEqual(<<"t">>, char_at(Cells, 0, 1)).

spans_are_contiguous_test() ->
    Cells = render_view(#{lines => [[{<<"ab">>, undefined}, {<<"cd">>, undefined}]]}),
    ?assertEqual(<<"c">>, char_at(Cells, 2, 0)),
    ?assertEqual(<<"d">>, char_at(Cells, 3, 0)).

wide_char_placeholder_test() ->
    Cells = render_view(#{lines => [[{<<"你好"/utf8>>, undefined}]]}),
    ?assertEqual(<<"你"/utf8>>, char_at(Cells, 0, 0)),
    %% second column is a zero-width placeholder
    ?assertEqual(0, (cell_at(Cells, 1, 0))#dui_cell.width),
    ?assertEqual(<<"好"/utf8>>, char_at(Cells, 2, 0)).

truncation_test() ->
    Cells = render_view(#{lines => [[{<<"abcdefghijkl">>, undefined}]]}),
    ?assertEqual(<<"j">>, char_at(Cells, 9, 0)),
    ?assertEqual(false, lists:search(
        fun({Cx, _Cy, _}) -> Cx =:= 10 end, Cells)).

base_style_merge_test() ->
    Cells = render_view(#{
        style => #{bg => blue},
        lines => [[{<<"x">>, #{fg => red}}]]
    }),
    Cell = cell_at(Cells, 0, 0),
    ?assertEqual(red, Cell#dui_cell.fg),
    ?assertEqual(blue, Cell#dui_cell.bg).

height_limit_test() ->
    Cells = render_view(#{lines => [
        [{<<"a">>, undefined}],
        [{<<"b">>, undefined}],
        [{<<"c">>, undefined}],
        [{<<"d">>, undefined}]
    ]}),
    ?assertEqual(<<"c">>, char_at(Cells, 0, 2)),
    ?assertEqual(false, lists:search(fun({_Cx, Cy, _}) -> Cy =:= 3 end, Cells)).
