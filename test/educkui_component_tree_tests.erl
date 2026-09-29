-module(educkui_component_tree_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

focus_cycle_and_editing_test() ->
    {ok, Pid} = educkui_runtime:start_link([{root, dui_form}, {skip_terminal, true}]),
    ok = educkui_runtime:force_render(Pid),
    ok = educkui_runtime:sync(Pid),

    %% Tab moves focus from root to the first component.
    educkui_runtime:send_event(Pid, educkui_event:key(tab)),
    ok = educkui_runtime:sync(Pid),
    S1 = educkui_runtime:get_state(Pid),
    ?assertEqual(name_input, hd(S1#dui_runtime_state.focus)),
    ?assertEqual([name_input, email_input], S1#dui_runtime_state.focus_order),

    %% Typing while focused edits the focused component.
    educkui_runtime:send_event(Pid, educkui_event:key(<<"X">>, [{char, <<"X">>}])),
    ok = educkui_runtime:sync(Pid),
    S2 = educkui_runtime:get_state(Pid),
    NameComp = maps:get(name_input, S2#dui_runtime_state.components),
    ?assertEqual(<<"AliceX">>, maps:get(value, NameComp#dui_component.state)),
    ?assertEqual(true, maps:get(focused, NameComp#dui_component.state)),

    %% Tab again moves focus to the next component.
    educkui_runtime:send_event(Pid, educkui_event:key(tab)),
    ok = educkui_runtime:sync(Pid),
    S3 = educkui_runtime:get_state(Pid),
    ?assertEqual(email_input, hd(S3#dui_runtime_state.focus)),
    EmailComp = maps:get(email_input, S3#dui_runtime_state.components),
    ?assertEqual(true, maps:get(focused, EmailComp#dui_component.state)),
    NameComp2 = maps:get(name_input, S3#dui_runtime_state.components),
    ?assertEqual(false, maps:get(focused, NameComp2#dui_component.state)),

    educkui_runtime:send_event(Pid, educkui_event:key(<<"h">>, [{char, <<"h">>}])),
    ok = educkui_runtime:sync(Pid),
    S4 = educkui_runtime:get_state(Pid),
    EmailComp2 = maps:get(email_input, S4#dui_runtime_state.components),
    ?assertEqual(<<"h">>, maps:get(value, EmailComp2#dui_component.state)),

    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

mouse_click_focuses_component_test() ->
    {ok, Pid} = educkui_runtime:start_link([{root, dui_form}, {skip_terminal, true}]),
    ok = educkui_runtime:force_render(Pid),
    ok = educkui_runtime:sync(Pid),

    %% email_input sits at row 2 (0-based y=2); click inside it focuses it.
    educkui_runtime:send_event(Pid, educkui_event:mouse(press, left, 5, 2)),
    ok = educkui_runtime:sync(Pid),
    S = educkui_runtime:get_state(Pid),
    ?assertEqual(email_input, hd(S#dui_runtime_state.focus)),
    EmailComp = maps:get(email_input, S#dui_runtime_state.components),
    ?assertEqual(true, maps:get(focused, EmailComp#dui_component.state)),

    ok = educkui_runtime:shutdown(Pid),
    wait_for_exit(Pid).

wait_for_exit(Pid) ->
    Ref = erlang:monitor(process, Pid),
    receive
        {'DOWN', Ref, process, Pid, _Reason} -> ok
    after 1000 ->
        ?assert(false)
    end.
