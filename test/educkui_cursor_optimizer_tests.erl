-module(educkui_cursor_optimizer_tests).

-include_lib("eunit/include/eunit.hrl").

new_position_test() ->
    C = educkui_cursor_optimizer:new(),
    ?assertEqual({1, 1}, educkui_cursor_optimizer:position(C)),
    C2 = educkui_cursor_optimizer:new(5, 10),
    ?assertEqual({5, 10}, educkui_cursor_optimizer:position(C2)).

same_position_test() ->
    C = educkui_cursor_optimizer:new(),
    {Seq, C2} = educkui_cursor_optimizer:move_to(C, 1, 1),
    ?assertEqual(<<>>, iolist_to_binary(Seq)),
    ?assertEqual(0, educkui_cursor_optimizer:bytes_saved(C2)).

small_right_move_uses_spaces_test() ->
    C = educkui_cursor_optimizer:new(),
    {Seq, _C2} = educkui_cursor_optimizer:move_to(C, 1, 4),
    ?assertEqual(<<"   ">>, iolist_to_binary(Seq)).

down_move_test() ->
    C = educkui_cursor_optimizer:new(),
    {Seq, _C2} = educkui_cursor_optimizer:move_to(C, 2, 1),
    ?assertEqual(<<"\e[B">>, iolist_to_binary(Seq)).

down_three_test() ->
    C = educkui_cursor_optimizer:new(),
    {Seq, _C2} = educkui_cursor_optimizer:move_to(C, 4, 1),
    ?assertEqual(<<"\e[3B">>, iolist_to_binary(Seq)).

left_move_test() ->
    C = educkui_cursor_optimizer:new(1, 10),
    {Seq, _C2} = educkui_cursor_optimizer:move_to(C, 1, 8),
    ?assertEqual(<<"\e[2D">>, iolist_to_binary(Seq)).

advance_test() ->
    C = educkui_cursor_optimizer:new(),
    C2 = educkui_cursor_optimizer:advance(C, 5),
    ?assertEqual({1, 6}, educkui_cursor_optimizer:position(C2)).

cost_absolute_test() ->
    ?assertEqual(6, educkui_cursor_optimizer:cost_absolute(1, 1)),
    ?assertEqual(7, educkui_cursor_optimizer:cost_absolute(10, 1)),
    ?assertEqual(9, educkui_cursor_optimizer:cost_absolute(100, 10)).

max_position_test() ->
    ?assertEqual(9999, educkui_cursor_optimizer:max_position()).
