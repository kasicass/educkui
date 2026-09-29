%% @doc Phase 0 smoke tests: application and supervision tree scaffolding.
-module(educkui_app_tests).

-include_lib("eunit/include/eunit.hrl").

modules_loaded_test() ->
    ?assertEqual({module, educkui_app}, code:ensure_loaded(educkui_app)),
    ?assertEqual({module, educkui_sup}, code:ensure_loaded(educkui_sup)).

sup_init_test() ->
    {ok, {SupFlags, Children}} = educkui_sup:init([]),
    ?assertEqual(one_for_one, maps:get(strategy, SupFlags)),
    ?assertEqual(5, maps:get(intensity, SupFlags)),
    ?assertEqual(10, maps:get(period, SupFlags)),
    ?assertEqual([], Children).

sup_start_stop_test() ->
    {ok, Pid} = educkui_sup:start_link(),
    ?assert(is_pid(Pid)),
    ?assert(is_process_alive(Pid)),
    unlink(Pid),
    exit(Pid, normal),
    receive
    after 100 -> ok
    end,
    ?assertNot(is_process_alive(Pid)).
