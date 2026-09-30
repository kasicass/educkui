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

%% The dialog declares its natural size, so it lays out as its box size
%% instead of being measured against a dummy rect (which used to be huge).
natural_size_test() ->
    Dialog = educkui_render_node:widget(educkui_widget_dialog,
        #{title => <<"T">>, width => 10, height => 5}),
    Filler = educkui_render_node:height(educkui_render_node:text(<<"X">>), 1),
    Stack = educkui_render_node:stack(vertical, [Dialog, Filler]),
    Cells = educkui_render:render(Stack, #dui_rect{x = 0, y = 0, width = 30, height = 20}),
    %% The dialog fills rows 0..4, so the filler lands on row 5.
    ?assertEqual(<<"X">>, char_at(Cells, 0, 5)).
