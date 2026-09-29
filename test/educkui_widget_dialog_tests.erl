-module(educkui_widget_dialog_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_dialog(Props) ->
    Node = educkui_widget_dialog:render(Props, #dui_rect{width = 30, height = 12}),
    Node#dui_node.cells.

char_at(Cells, X, Y) ->
    Matches = [{Cx, Cy, Cell} || {Cx, Cy, Cell} <- Cells, Cx =:= X, Cy =:= Y],
    {_X, _Y, Cell} = lists:last(Matches),
    Cell#dui_cell.char.

border_test() ->
    Cells = render_dialog(#{title => <<"T">>, width => 10, height => 5}),
    %% centered: BX = (30-10) div 2 = 10, BY = (12-5) div 2 = 3.
    ?assertEqual(<<"┌"/utf8>>, char_at(Cells, 10, 3)),
    ?assertEqual(<<"┘"/utf8>>, char_at(Cells, 19, 7)).

title_test() ->
    Cells = render_dialog(#{title => <<"Hi">>, width => 10, height => 5}),
    %% title at BX+2=12, BY+1=4
    ?assertEqual(<<"H">>, char_at(Cells, 12, 4)),
    ?assertEqual(<<"i">>, char_at(Cells, 13, 4)).
