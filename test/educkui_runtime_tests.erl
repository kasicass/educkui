-module(educkui_runtime_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

counter_updates_test() ->
    {ok, Pid} = educkui_runtime:start_link([{root, dui_counter}, {skip_terminal, true}]),
    educkui_runtime:send_event(Pid, educkui_event:key(up)),
    educkui_runtime:send_event(Pid, educkui_event:key(up)),
    ok = educkui_runtime:sync(Pid),
    State = educkui_runtime:get_state(Pid),
    ?assertEqual(2, maps:get(count, State#dui_runtime_state.root_state)),
    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

counter_renders_buffer_test() ->
    {ok, Pid} = educkui_runtime:start_link([{root, dui_counter}, {skip_terminal, true}]),
    ok = educkui_runtime:sync(Pid),
    ok = educkui_runtime:force_render(Pid),
    ok = educkui_runtime:sync(Pid),
    State = educkui_runtime:get_state(Pid),
    %% Previous buffer holds the just-rendered frame. The first row must be
    %% horizontal: "Counter: 0".
    PrevBuf = State#dui_runtime_state.previous_buffer,
    ?assertEqual(<<"C">>, (educkui_buffer:get_cell(PrevBuf, 1, 1))#dui_cell.char),
    ?assertEqual(<<"o">>, (educkui_buffer:get_cell(PrevBuf, 1, 2))#dui_cell.char),
    ?assertEqual(<<" ">>, (educkui_buffer:get_cell(PrevBuf, 1, 9))#dui_cell.char),
    ?assertEqual(<<"0">>, (educkui_buffer:get_cell(PrevBuf, 1, 10))#dui_cell.char),
    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

skip_terminal_backend_mode_test() ->
    {ok, Pid} = educkui_runtime:start_link([{root, dui_counter}, {skip_terminal, true}]),
    ?assertEqual(skip, educkui_runtime:backend_mode()),
    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

skip_backend_size_option_test() ->
    {ok, Pid} = educkui_runtime:start_link(
        [{root, dui_counter}, {skip_terminal, true}, {size, {30, 100}}]),
    ok = educkui_runtime:sync(Pid),
    S = educkui_runtime:get_state(Pid),
    ?assertEqual({30, 100}, S#dui_runtime_state.dimensions),
    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

resize_event_test() ->
    {ok, Pid} = educkui_runtime:start_link([{root, dui_counter}, {skip_terminal, true}]),
    ok = educkui_runtime:sync(Pid),
    S0 = educkui_runtime:get_state(Pid),
    ?assertEqual({24, 80}, S0#dui_runtime_state.dimensions),
    educkui_runtime:send_event(Pid, educkui_event:resize(120, 40)),
    ok = educkui_runtime:sync(Pid),
    S1 = educkui_runtime:get_state(Pid),
    ?assertEqual({40, 120}, S1#dui_runtime_state.dimensions),
    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

command_result_returns_to_root_test() ->
    {ok, Pid} = educkui_runtime:start_link([{root, dui_probe}, {skip_terminal, true}]),
    educkui_runtime:send_event(Pid, educkui_event:key(run)),
    ok = wait_until(Pid, fun(S) -> maps:get(result, S) =:= 42 end),
    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

interval_delivers_and_cancels_test() ->
    {ok, Pid} = educkui_runtime:start_link([{root, dui_probe}, {skip_terminal, true}]),
    educkui_runtime:send_event(Pid, educkui_event:key(start_timer)),
    ok = wait_until(Pid, fun(S) -> maps:get(ticks, S) >= 1 end),
    educkui_runtime:send_event(Pid, educkui_event:key(cancel_timer)),
    timer:sleep(60),
    ok = educkui_runtime:sync(Pid),
    S1 = educkui_runtime:get_state(Pid),
    Ticks1 = maps:get(ticks, S1#dui_runtime_state.root_state),
    timer:sleep(80),
    ok = educkui_runtime:sync(Pid),
    S2 = educkui_runtime:get_state(Pid),
    Ticks2 = maps:get(ticks, S2#dui_runtime_state.root_state),
    ?assertEqual(Ticks1, Ticks2),
    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

root_receives_initial_size_test() ->
    {ok, Pid} = educkui_runtime:start_link([{root, dui_probe}, {skip_terminal, true}]),
    ok = educkui_runtime:sync(Pid),
    S = educkui_runtime:get_state(Pid),
    ?assertEqual({80, 24}, maps:get(size, S#dui_runtime_state.root_state)),
    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

%% With no focusable child components, Tab is delivered to the root so
%% applications can implement their own field navigation.
tab_reaches_root_without_focusable_components_test() ->
    {ok, Pid} = educkui_runtime:start_link([{root, dui_probe}, {skip_terminal, true}]),
    ok = educkui_runtime:sync(Pid),
    educkui_runtime:send_event(Pid, educkui_event:key(tab)),
    ok = wait_until(Pid, fun(S) -> maps:get(last_key, S) =:= tab end),
    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

root_receives_resize_test() ->
    {ok, Pid} = educkui_runtime:start_link([{root, dui_probe}, {skip_terminal, true}]),
    ok = educkui_runtime:sync(Pid),
    educkui_runtime:send_event(Pid, educkui_event:resize(100, 30)),
    ok = educkui_runtime:sync(Pid),
    S = educkui_runtime:get_state(Pid),
    ?assertEqual({100, 30}, maps:get(size, S#dui_runtime_state.root_state)),
    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

wait_until(Pid, Pred) ->
    wait_until(Pid, Pred, 50).

wait_until(Pid, Pred, 0) ->
    State = educkui_runtime:get_state(Pid),
    ?assert(Pred(State#dui_runtime_state.root_state));
wait_until(Pid, Pred, N) ->
    ok = educkui_runtime:sync(Pid),
    State = educkui_runtime:get_state(Pid),
    case Pred(State#dui_runtime_state.root_state) of
        true -> ok;
        false -> timer:sleep(10), wait_until(Pid, Pred, N - 1)
    end.

wait_for_exit(Pid) ->
    Ref = erlang:monitor(process, Pid),
    receive
        {'DOWN', Ref, process, Pid, _Reason} -> ok
    after 1000 ->
        ?assert(false)
    end.
