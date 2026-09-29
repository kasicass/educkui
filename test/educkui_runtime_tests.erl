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

wait_for_exit(Pid) ->
    Ref = erlang:monitor(process, Pid),
    receive
        {'DOWN', Ref, process, Pid, _Reason} -> ok
    after 1000 ->
        ?assert(false)
    end.
