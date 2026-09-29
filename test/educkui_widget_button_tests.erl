-module(educkui_widget_button_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_button(Props) ->
    Node = educkui_widget_button:render(Props, #dui_rect{width = 10, height = 3}),
    Node#dui_node.cells.

border_chars_test() ->
    Cells = render_button(#{label => <<"OK">>}),
    ?assertEqual(<<"["/utf8>>, char_at(Cells, 0, 0)),
    ?assertEqual(<<"]"/utf8>>, char_at(Cells, 9, 0)).

label_centered_test() ->
    Cells = render_button(#{label => <<"OK">>}),
    %% Inner width is 8; "OK" centered => starts at x=1+3=4.
    ?assertEqual(<<"O">>, char_at(Cells, 4, 1)),
    ?assertEqual(<<"K">>, char_at(Cells, 5, 1)).

focused_test() ->
    Cells = render_button(#{label => <<"OK">>, focused => true,
                            focus_style => #{fg => blue}}),
    ?assertEqual(blue, fg_at(Cells, 4, 1)).

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
