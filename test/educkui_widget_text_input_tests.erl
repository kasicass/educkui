-module(educkui_widget_text_input_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

init_test() ->
    S = educkui_widget_text_input:init([{value, <<"ab">>}]),
    ?assertEqual(<<"ab">>, maps:get(value, S)),
    ?assertEqual(2, maps:get(cursor, S)),
    ?assertEqual(false, maps:get(focused, S)).

insert_test() ->
    S0 = educkui_widget_text_input:init([{value, <<"ab">>}]),
    {S1, []} = educkui_widget_text_input:update({insert, <<"X">>}, S0),
    ?assertEqual(<<"abX">>, maps:get(value, S1)).

backspace_test() ->
    S0 = educkui_widget_text_input:init([{value, <<"abc">>}]),
    {S1, []} = educkui_widget_text_input:update(backspace, S0),
    ?assertEqual(<<"ab">>, maps:get(value, S1)).

cursor_set_test() ->
    S0 = educkui_widget_text_input:init([{value, <<"abcd">>}]),
    {msg, {cursor_set, 2}} =
        educkui_widget_text_input:event_to_msg(
            educkui_event:mouse(press, left, 2, 0), S0),
    {S1, []} = educkui_widget_text_input:update({cursor_set, 2}, S0),
    ?assertEqual(2, maps:get(cursor, S1)),
    {S2, []} = educkui_widget_text_input:update({cursor_set, 99}, S1),
    ?assertEqual(4, maps:get(cursor, S2)).

view_empty_has_one_cell_test() ->
    S = educkui_widget_text_input:init([{value, <<>>}]),
    Node = educkui_widget_text_input:view(S),
    ?assertEqual(1, length(Node#dui_node.cells)).
