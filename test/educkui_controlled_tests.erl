-module(educkui_controlled_tests).

-include_lib("eunit/include/eunit.hrl").

controlled_text_input_test() ->
    Pid = educkui_test:start(#{root => dui_controlled}),
    ok = educkui_test:render(Pid),
    {ok, S0} = educkui_test:get_component_state(Pid, input),
    ?assertEqual(<<"a">>, maps:get(value, S0)),
    ok = educkui_test:set_props(Pid, input, #{value => <<"xyz">>}),
    ok = educkui_test:sync(Pid),
    {ok, S1} = educkui_test:get_component_state(Pid, input),
    ?assertEqual(<<"xyz">>, maps:get(value, S1)),
    ?assertEqual(3, maps:get(cursor, S1)),
    ok = educkui_test:stop(Pid).

handle_props_callback_test() ->
    Pid = educkui_test:start(#{root => dui_controlled}),
    ok = educkui_test:render(Pid),
    ok = educkui_test:set_props(Pid, settings, #{count => 7}),
    ok = educkui_test:sync(Pid),
    {ok, S} = educkui_test:get_component_state(Pid, settings),
    ?assertEqual(7, maps:get(count, S)),
    ok = educkui_test:stop(Pid).

unknown_component_test() ->
    Pid = educkui_test:start(#{root => dui_controlled}),
    ok = educkui_test:render(Pid),
    ?assertEqual(error, educkui_test:get_component_state(Pid, missing)),
    ok = educkui_test:set_props(Pid, missing, #{}),
    ok = educkui_test:sync(Pid),
    ok = educkui_test:stop(Pid).
