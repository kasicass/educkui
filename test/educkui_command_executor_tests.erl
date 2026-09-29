-module(educkui_command_executor_tests).

-include_lib("eunit/include/eunit.hrl").

noop_test() ->
    {ok, Pid} = educkui_command_executor:start_link(),
    ok = educkui_command_executor:execute(Pid, widget, [educkui_command:noop()], self()),
    %% Give the cast time to be processed; nothing should be delivered.
    receive
        _Unexpected -> ?assert(false)
    after 50 -> ok
    end,
    gen_server:stop(Pid).

quit_test() ->
    {ok, Pid} = educkui_command_executor:start_link(),
    ok = educkui_command_executor:execute(Pid, widget, [educkui_command:quit()], self()),
    receive
        {educkui_command, quit} -> ok
    after 500 -> ?assert(false)
    end,
    gen_server:stop(Pid).

send_msg_test() ->
    {ok, Pid} = educkui_command_executor:start_link(),
    Target = spawn(fun() ->
        receive
            hello -> ok
        end
    end),
    ok = educkui_command_executor:execute(Pid, widget,
        [educkui_command:send_msg(Target, hello)], self()),
    timer:sleep(50),
    gen_server:stop(Pid).

exec_test() ->
    {ok, Pid} = educkui_command_executor:start_link(),
    ok = educkui_command_executor:execute(Pid, widget,
        [educkui_command:exec(fun() -> 42 end)], self()),
    receive
        {command_result, widget, 42} -> ok
    after 500 -> ?assert(false)
    end,
    gen_server:stop(Pid).
