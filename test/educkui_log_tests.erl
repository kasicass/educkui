-module(educkui_log_tests).

-include_lib("eunit/include/eunit.hrl").

log_buffer_test() ->
    {ok, Pid} = educkui_log:ensure_started(),
    ok = educkui_log:clear(),
    ok = educkui_log:add(#{msg => one}),
    ok = educkui_log:add(#{msg => two}),
    ?assertEqual([#{msg => one}, #{msg => two}], educkui_log:entries()),
    ?assertEqual([#{msg => one}], educkui_log:entries(1)),
    ok = educkui_log:clear(),
    ?assertEqual([], educkui_log:entries()),
    {ok, Pid} = educkui_log:ensure_started(),
    gen_server:stop(Pid).

bounded_test() ->
    {ok, Pid} = educkui_log:ensure_started(),
    ok = educkui_log:clear(),
    lists:foreach(fun(I) -> ok = educkui_log:add(I) end, lists:seq(1, 1005)),
    Entries = educkui_log:entries(),
    ?assertEqual(1000, length(Entries)),
    ?assertEqual(6, hd(Entries)),
    ?assertEqual(1005, lists:last(Entries)),
    gen_server:stop(Pid).

not_running_is_safe_test() ->
    case whereis(educkui_log) of
        undefined -> ok;
        Pid -> gen_server:stop(Pid)
    end,
    ?assertEqual([], educkui_log:entries()),
    ?assertEqual(ok, educkui_log:add(#{msg => dropped})),
    ?assertEqual(ok, educkui_log:clear()).

handler_forwards_test() ->
    {ok, Pid} = educkui_log:ensure_started(),
    ok = educkui_log:clear(),
    Event = #{level => info, msg => {string, "hello"}, meta => #{}},
    ok = educkui_log_handler:log(Event, #{}),
    ?assertEqual([Event], educkui_log:entries()),
    gen_server:stop(Pid).
