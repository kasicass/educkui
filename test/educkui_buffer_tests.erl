-module(educkui_buffer_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

new_and_dimensions_test() ->
    {ok, Buf} = educkui_buffer:new(10, 80),
    ?assertEqual({10, 80}, educkui_buffer:dimensions(Buf)),
    ?assertEqual(10, Buf#dui_buffer.rows),
    ?assertEqual(80, Buf#dui_buffer.cols),
    educkui_buffer:destroy(Buf).

empty_cells_test() ->
    {ok, Buf} = educkui_buffer:new(2, 2),
    Cell = educkui_buffer:get_cell(Buf, 1, 1),
    ?assert(educkui_cell:empty(Cell)),
    educkui_buffer:destroy(Buf).

set_and_get_test() ->
    {ok, Buf} = educkui_buffer:new(2, 2),
    Cell = educkui_cell:new(<<"X">>, [{fg, red}]),
    ok = educkui_buffer:set_cell(Buf, 1, 1, Cell),
    ?assert(educkui_cell:equal(Cell, educkui_buffer:get_cell(Buf, 1, 1))),
    educkui_buffer:destroy(Buf).

set_cells_test() ->
    {ok, Buf} = educkui_buffer:new(2, 2),
    Cells = [{1, 1, educkui_cell:new(<<"A">>)}, {1, 2, educkui_cell:new(<<"B">>)}],
    ok = educkui_buffer:set_cells(Buf, Cells),
    ?assertEqual(<<"A">>, (educkui_buffer:get_cell(Buf, 1, 1))#dui_cell.char),
    ?assertEqual(<<"B">>, (educkui_buffer:get_cell(Buf, 1, 2))#dui_cell.char),
    educkui_buffer:destroy(Buf).

out_of_bounds_test() ->
    {ok, Buf} = educkui_buffer:new(2, 2),
    ?assertEqual({error, out_of_bounds},
                 educkui_buffer:set_cell(Buf, 3, 1, educkui_cell:new(<<"X">>))),
    ?assert(educkui_cell:empty(educkui_buffer:get_cell(Buf, 9, 9))),
    educkui_buffer:destroy(Buf).

clear_region_test() ->
    {ok, Buf} = educkui_buffer:new(3, 3),
    ok = educkui_buffer:set_cell(Buf, 1, 1, educkui_cell:new(<<"X">>)),
    ok = educkui_buffer:set_cell(Buf, 2, 2, educkui_cell:new(<<"Y">>)),
    ok = educkui_buffer:clear_region(Buf, 1, 1, 2, 2),
    ?assert(educkui_cell:empty(educkui_buffer:get_cell(Buf, 1, 1))),
    ?assert(educkui_cell:empty(educkui_buffer:get_cell(Buf, 2, 2))),
    educkui_buffer:destroy(Buf).

clear_test() ->
    {ok, Buf} = educkui_buffer:new(2, 2),
    ok = educkui_buffer:set_cell(Buf, 1, 1, educkui_cell:new(<<"X">>)),
    ok = educkui_buffer:clear(Buf),
    ?assert(educkui_cell:empty(educkui_buffer:get_cell(Buf, 1, 1))),
    educkui_buffer:destroy(Buf).

get_row_test() ->
    {ok, Buf} = educkui_buffer:new(2, 3),
    ok = educkui_buffer:set_cell(Buf, 1, 2, educkui_cell:new(<<"B">>)),
    Row = educkui_buffer:get_row(Buf, 1),
    ?assertEqual(3, length(Row)),
    ?assertEqual(<<"B">>, (lists:nth(2, Row))#dui_cell.char),
    educkui_buffer:destroy(Buf).

resize_test() ->
    {ok, Buf} = educkui_buffer:new(2, 2),
    ok = educkui_buffer:set_cell(Buf, 1, 1, educkui_cell:new(<<"X">>)),
    {ok, Bigger} = educkui_buffer:resize(Buf, 5, 5),
    ?assertEqual({5, 5}, educkui_buffer:dimensions(Bigger)),
    ?assertEqual(<<"X">>, (educkui_buffer:get_cell(Bigger, 1, 1))#dui_cell.char),
    ?assert(educkui_cell:empty(educkui_buffer:get_cell(Bigger, 5, 5))),
    educkui_buffer:destroy(Bigger).

write_string_test() ->
    {ok, Buf} = educkui_buffer:new(1, 10),
    ?assertEqual(5, educkui_buffer:write_string(Buf, 1, 1, <<"Hello">>)),
    ?assertEqual(<<"H">>, (educkui_buffer:get_cell(Buf, 1, 1))#dui_cell.char),
    ?assertEqual(<<"o">>, (educkui_buffer:get_cell(Buf, 1, 5))#dui_cell.char),
    educkui_buffer:destroy(Buf).

write_string_wide_test() ->
    {ok, Buf} = educkui_buffer:new(1, 10),
    ?assertEqual(2, educkui_buffer:write_string(Buf, 1, 1, <<"日"/utf8>>)),
    ?assert(educkui_cell:wide(educkui_buffer:get_cell(Buf, 1, 1))),
    ?assert(educkui_cell:is_wide_placeholder(educkui_buffer:get_cell(Buf, 1, 2))),
    educkui_buffer:destroy(Buf).

max_dimensions_test() ->
    ?assertMatch({error, {dimensions_too_large, _, _, _, _}},
                 educkui_buffer:new(600, 10)),
    ?assertMatch({error, {dimensions_too_large, _, _, _, _}},
                 educkui_buffer:new(10, 2000)).

to_list_test() ->
    {ok, Buf} = educkui_buffer:new(2, 2),
    ok = educkui_buffer:set_cell(Buf, 2, 2, educkui_cell:new(<<"Z">>)),
    List = educkui_buffer:to_list(Buf),
    ?assertEqual(4, length(List)),
    {_R, _C, LastCell} = lists:last(List),
    ?assertEqual(<<"Z">>, LastCell#dui_cell.char),
    educkui_buffer:destroy(Buf).
