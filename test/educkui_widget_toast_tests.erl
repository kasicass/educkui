-module(educkui_widget_toast_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_toast(Props) ->
    Node = educkui_widget_toast:render(Props, #dui_rect{width = 20, height = 6}),
    Node#dui_node.cells.

char_at(Cells, X, Y) ->
    Matches = [{Cx, Cy, Cell} || {Cx, Cy, Cell} <- Cells, Cx =:= X, Cy =:= Y],
    {_X, _Y, Cell} = lists:last(Matches),
    Cell#dui_cell.char.

message_test() ->
    Cells = render_toast(#{message => <<"saved">>}),
    %% box at bottom: BY = 6-3 = 3; message at BX+2, BY+1=4.
    %% BX = (20 - (5+4)) div 2 = (20-9) div 2 = 5.
    ?assertEqual(<<"s">>, char_at(Cells, 7, 4)).
