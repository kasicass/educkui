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

offset_test() ->
    Cells = render_list(#{items => [<<"a">>, <<"b">>, <<"c">>], offset => 1,
                          selected => 2}),
    ?assertEqual(<<"b">>, char_at(Cells, 0, 0)),
    ?assertEqual(<<"c">>, char_at(Cells, 0, 1)),
    %% global index 2 ("c") is selected
    ?assertEqual(red, fg_at(render_list(#{items => [<<"a">>, <<"b">>, <<"c">>],
                                          offset => 1, selected => 2,
                                          selected_style => #{fg => red}}), 0, 1)).

visible_range_test() ->
    ?assertEqual({0, 3}, educkui_widget_list:visible_range(3, 0, 3)),
    %% selection below the window scrolls down minimally
    ?assertEqual({2, 3}, educkui_widget_list:visible_range(10, 4, 3)),
    %% selection above the window scrolls up
    ?assertEqual({1, 3}, educkui_widget_list:visible_range(10, 1, 3, 4)),
    %% clamps to the end
    ?assertEqual({7, 3}, educkui_widget_list:visible_range(10, 9, 3)),
    %% degenerate height
    ?assertEqual({0, 0}, educkui_widget_list:visible_range(10, 5, 0)).

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
