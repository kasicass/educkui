-module(educkui_shortcut_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

match_exact_test() ->
    Ev = educkui_event:key(<<"q">>, [{modifiers, [ctrl]}]),
    ?assert(educkui_shortcut:match(Ev, {<<"q">>, [ctrl]})),
    ?assertNot(educkui_shortcut:match(Ev, {<<"q">>, [shift]})),
    ?assertNot(educkui_shortcut:match(Ev, {<<"x">>, [ctrl]})).

match_atom_key_test() ->
    Ev = educkui_event:key(enter),
    ?assert(educkui_shortcut:match(Ev, {enter, []})),
    ?assertNot(educkui_shortcut:match(Ev, {enter, [ctrl]})).

find_test() ->
    Ev = educkui_event:key(<<"c">>, [{modifiers, [ctrl]}]),
    Shortcuts = [{{<<"q">>, [ctrl]}, quit_cmd},
                 {{<<"c">>, [ctrl]}, copy_cmd}],
    ?assertEqual({ok, copy_cmd}, educkui_shortcut:find(Ev, Shortcuts)),
    ?assertEqual(none, educkui_shortcut:find(
        educkui_event:key(<<"z">>), Shortcuts)).

runtime_shortcut_quit_test() ->
    {ok, Pid} = educkui_runtime:start_link([
        {root, dui_form},
        {skip_terminal, true},
        {shortcuts, [{{<<"q">>, [ctrl]}, educkui_command:quit()}]}
    ]),
    educkui_runtime:send_event(Pid, educkui_event:key(<<"q">>, [{modifiers, [ctrl]}])),
    Ref = erlang:monitor(process, Pid),
    receive
        {'DOWN', Ref, process, Pid, _Reason} -> ok
    after 1000 ->
        ?assert(false)
    end.
