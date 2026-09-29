-module(educkui_input_raw_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

queued_event_test() ->
    Ev = educkui_event:key(up),
    State = #{buffer => <<>>, event_queue => [Ev]},
    {{ok, Ev2}, _} = educkui_input_raw:poll(State, 0),
    ?assertEqual(up, Ev2#dui_event.key).

data_message_test() ->
    self() ! {educkui_input, <<"a">>},
    {{ok, Ev}, _} = educkui_input_raw:poll(educkui_input_raw:new(), 100),
    ?assertEqual(key, Ev#dui_event.type),
    ?assertEqual(<<"a">>, Ev#dui_event.key).

split_escape_sequence_test() ->
    self() ! {educkui_input, <<27, $[>>},
    {R1, S1} = educkui_input_raw:poll(educkui_input_raw:new(), 50),
    ?assertEqual(timeout, R1),
    self() ! {educkui_input, <<"A">>},
    {{ok, Ev}, _} = educkui_input_raw:poll(S1, 50),
    ?assertEqual(up, Ev#dui_event.key).

timeout_test() ->
    {timeout, _} = educkui_input_raw:poll(educkui_input_raw:new(), 0).

mode_test() ->
    ?assertEqual(raw, educkui_input_raw:mode(educkui_input_raw:new())).
