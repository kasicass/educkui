-module(educkui_command_tests).

-include_lib("eunit/include/eunit.hrl").

constructors_test() ->
    ?assertEqual({quit}, educkui_command:quit()),
    ?assertEqual({noop}, educkui_command:noop()),
    ?assertEqual({send, self(), hi}, educkui_command:send_msg(self(), hi)).

exec_test() ->
    Fun = fun() -> 42 end,
    ?assertEqual({exec, Fun}, educkui_command:exec(Fun)).
