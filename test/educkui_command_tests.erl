-module(educkui_command_tests).

-include_lib("eunit/include/eunit.hrl").

constructors_test() ->
    ?assertEqual({quit}, educkui_command:quit()),
    ?assertEqual({noop}, educkui_command:noop()),
    ?assertEqual({send, self(), hi}, educkui_command:send_msg(self(), hi)).

exec_test() ->
    Fun = fun() -> 42 end,
    ?assertEqual({exec, Fun}, educkui_command:exec(Fun)).

interval_test() ->
    ?assertMatch({interval, undefined, tick, 1000},
                 educkui_command:interval(tick, 1000)).

interval_with_ref_test() ->
    Ref = make_ref(),
    ?assertEqual({interval, Ref, tick, 250}, educkui_command:interval(Ref, tick, 250)).

cancel_interval_test() ->
    Ref = make_ref(),
    ?assertEqual({cancel_interval, Ref}, educkui_command:cancel_interval(Ref)).
