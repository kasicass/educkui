-module(educkui_test_tests).

-include_lib("eunit/include/eunit.hrl").

screen_text_test() ->
    Pid = educkui_test:start(#{root => dui_counter}),
    ?assertMatch({_, _}, binary:match(educkui_test:screen_text(Pid), <<"Counter: 0">>)),
    ok = educkui_test:stop(Pid).

send_key_updates_state_test() ->
    Pid = educkui_test:start(#{root => dui_counter}),
    ok = educkui_test:send_key(Pid, up),
    ok = educkui_test:send_key(Pid, up),
    ?assertEqual(ok, educkui_test:wait_until(Pid, fun(S) -> maps:get(count, S) =:= 2 end)),
    ?assertEqual(ok, educkui_test:assert_text(Pid, <<"Counter: 2">>)),
    ok = educkui_test:stop(Pid).

assert_text_missing_test() ->
    Pid = educkui_test:start(#{root => dui_counter}),
    ?assertEqual({error, {not_found, <<"nope">>}},
                 educkui_test:assert_text(Pid, <<"nope">>)),
    ok = educkui_test:stop(Pid).

assert_text_raises_test() ->
    Pid = educkui_test:start(#{root => dui_counter}),
    ?assertError({assert_text_failed, _, ctx},
                 educkui_test:assert_text(Pid, <<"nope">>, ctx)),
    ok = educkui_test:stop(Pid).

async_command_via_harness_test() ->
    Pid = educkui_test:start(#{root => dui_probe}),
    ok = educkui_test:send_key(Pid, run),
    ?assertEqual(ok, educkui_test:wait_until(Pid, fun(S) -> maps:get(result, S) =:= 42 end)),
    ok = educkui_test:stop(Pid).

screen_cells_test() ->
    Pid = educkui_test:start(#{root => dui_counter, size => {10, 20}}),
    Cells = educkui_test:screen_cells(Pid),
    ?assert(length(Cells) > 0),
    ok = educkui_test:stop(Pid).
