-module(educkui_widget_push_button_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

init_test() ->
    S = educkui_widget_push_button:init([{label, <<"OK">>}, {id, ok_btn}]),
    ?assertEqual(<<"OK">>, maps:get(label, S)),
    ?assertEqual(ok_btn, maps:get(id, S)),
    ?assertEqual(false, maps:get(focused, S)).

activate_test() ->
    S = educkui_widget_push_button:init([{label, <<"OK">>}, {id, ok_btn}]),
    {msg, activate} = educkui_widget_push_button:event_to_msg(
        educkui_event:key(enter), S),
    {S1, [{parent, {button, ok_btn}}]} =
        educkui_widget_push_button:update(activate, S),
    ?assertEqual(<<"OK">>, maps:get(label, S1)).

focus_test() ->
    S0 = educkui_widget_push_button:init([{label, <<"OK">>}, {id, ok_btn}]),
    {S1, []} = educkui_widget_push_button:update(focus_gained, S0),
    ?assertEqual(true, maps:get(focused, S1)),
    {S2, []} = educkui_widget_push_button:update(focus_lost, S1),
    ?assertEqual(false, maps:get(focused, S2)).

view_test() ->
    S = educkui_widget_push_button:init([{label, <<"OK">>}, {id, ok_btn}]),
    Node = educkui_widget_push_button:view(S),
    ?assertEqual(<<"[OK]">>, Node#dui_node.content).
