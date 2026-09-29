-module(educkui_render_overlay_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

cell_at(Cells, X, Y) ->
    %% Overlays may produce several cells at the same position; the last one
    %% wins (matching ETS `set_cells` semantics).
    Matches = [{Cx, Cy, Cell} || {Cx, Cy, Cell} <- Cells, Cx =:= X, Cy =:= Y],
    {_X, _Y, Cell} = lists:last(Matches),
    Cell.

overlay_covers_base_test() ->
    Base = educkui_render_node:text(<<"base">>),
    Top = educkui_render_node:box([],
        [{style, educkui_style:from([{bg, red}])}]),
    View = educkui_render_node:overlay([Base, Top]),
    Cells = educkui_render:render(View, #dui_rect{width = 4, height = 1}),
    %% The top box (bg red) covers the base text.
    Cell = cell_at(Cells, 0, 0),
    ?assertEqual(red, Cell#dui_cell.bg),
    ?assertEqual(<<" ">>, Cell#dui_cell.char).

overlay_order_test() ->
    First = educkui_render_node:cells([{0, 0, educkui_cell:new(<<"a">>)}]),
    Second = educkui_render_node:cells([{0, 0, educkui_cell:new(<<"b">>)}]),
    View = educkui_render_node:overlay([First, Second]),
    Cells = educkui_render:render(View, #dui_rect{width = 1, height = 1}),
    %% Later child wins.
    ?assertEqual(<<"b">>, (cell_at(Cells, 0, 0))#dui_cell.char).
