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

%% Small right moves must NOT use spaces: writing spaces would erase any
%% unchanged character occupying the skipped cells.
small_right_move_uses_cursor_forward_test() ->
    C = educkui_cursor_optimizer:new(),
    {Seq, _C2} = educkui_cursor_optimizer:move_to(C, 1, 4),
    ?assertEqual(<<"\e[3C">>, iolist_to_binary(Seq)).

no_space_bytes_test() ->
    Cases = [{1, 1, 1, 4}, {1, 4, 1, 1}, {2, 1, 1, 5}, {1, 5, 4, 2},
             {3, 7, 1, 3}, {1, 1, 2, 2}],
    lists:foreach(
        fun({R1, C1, R2, C2}) ->
            C = educkui_cursor_optimizer:new(R1, C1),
            {Seq, _} = educkui_cursor_optimizer:move_to(C, R2, C2),
            Bin = iolist_to_binary(Seq),
            ?assertEqual(nomatch, binary:match(Bin, <<" ">>))
        end,
        Cases).

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
