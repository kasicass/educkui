-module(educkui_elm_tests).

-include_lib("eunit/include/eunit.hrl").

normalize_init_plain_test() ->
    ?assertEqual({#{count => 0}, []},
                 educkui_elm:normalize_init_result(#{count => 0})).

normalize_init_ok_test() ->
    ?assertEqual({ok_state, []},
                 educkui_elm:normalize_init_result({ok, ok_state})).

normalize_init_ok_with_commands_test() ->
    ?assertEqual({ok_state, [cmd]},
                 educkui_elm:normalize_init_result({ok, ok_state, [cmd]})).

normalize_init_with_commands_test() ->
    ?assertEqual({state, [cmd1, cmd2]},
                 educkui_elm:normalize_init_result({state, [cmd1, cmd2]})).

normalize_update_with_commands_test() ->
    ?assertEqual({new_state, [cmd]},
                 educkui_elm:normalize_update_result({new_state, [cmd]}, old)).

normalize_update_shorthand_test() ->
    ?assertEqual({new_state, []},
                 educkui_elm:normalize_update_result({new_state}, old)).

normalize_update_noreply_test() ->
    ?assertEqual({old, []},
                 educkui_elm:normalize_update_result(noreply, old)).
