-module(educkui_render_layout_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

char_at(Cells, X, Y) ->
    {value, {_X, _Y, Cell}} = lists:search(
        fun({Cx, Cy, _}) -> Cx =:= X andalso Cy =:= Y end, Cells),
    Cell#dui_cell.char.

vertical_stack_one_row_each_test() ->
    View = educkui_render_node:stack(vertical, [
        educkui_render_node:text(<<"a">>),
        educkui_render_node:text(<<"b">>)
    ]),
    Cells = educkui_render:render(View, #dui_rect{width = 5, height = 5}),
    ?assertEqual(<<"a">>, char_at(Cells, 0, 0)),
    ?assertEqual(<<"b">>, char_at(Cells, 0, 1)).

center_align_test() ->
    View = educkui_render_node:stack(vertical, [
        educkui_render_node:text(<<"a">>),
        educkui_render_node:text(<<"b">>)
    ], [{align, center}]),
    Cells = educkui_render:render(View, #dui_rect{width = 5, height = 5}),
    ?assertEqual(<<"a">>, char_at(Cells, 0, 1)),
    ?assertEqual(<<"b">>, char_at(Cells, 0, 2)).

horizontal_flex_test() ->
    View = educkui_render_node:stack(horizontal, [
        educkui_render_node:text(<<"L">>),
        educkui_render_node:width(educkui_render_node:text(<<"R">>), auto)
    ]),
    Cells = educkui_render:render(View, #dui_rect{width = 5, height = 1}),
    ?assertEqual(<<"L">>, char_at(Cells, 0, 0)),
    ?assertEqual(<<"R">>, char_at(Cells, 1, 0)).

widget_node_test() ->
    View = educkui_render_node:widget(educkui_widget_gauge, #{value => 1.0}),
    Cells = educkui_render:render(View, #dui_rect{width = 2, height = 1}),
    %% two bar cells; the first is the filled gauge cell.
    {_X, _Y, Cell} = hd(Cells),
    ?assertEqual(<<"█"/utf8>>, Cell#dui_cell.char).

explicit_height_test() ->
    View = educkui_render_node:stack(vertical, [
        educkui_render_node:text(<<"a">>),
        educkui_render_node:box([], [{height, 3}])
    ]),
    Cells = educkui_render:render(View, #dui_rect{width = 5, height = 10}),
    ?assertEqual(<<"a">>, char_at(Cells, 0, 0)).
