-module(educkui_widget_pick_list_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

init_test() ->
    S = educkui_widget_pick_list:init([{items, [<<"apple">>, <<"banana">>]},
                                       {selected, 1}, {prompt, <<"Fruit: ">>}]),
    ?assertEqual([<<"apple">>, <<"banana">>], maps:get(items, S)),
    ?assertEqual(1, maps:get(selected, S)),
    ?assertEqual(<<"Fruit: ">>, maps:get(prompt, S)),
    ?assertEqual(<<>>, maps:get(filter, S)),
    ?assertEqual(false, maps:get(focused, S)).

filtering_test() ->
    S0 = educkui_widget_pick_list:init([{items, [<<"apple">>, <<"banana">>, <<"cherry">>]}]),
    {msg, {filter_char, <<"a">>}} =
        educkui_widget_pick_list:event_to_msg(educkui_event:key(<<"a">>, [{char, <<"a">>}]), S0),
    {S1, []} = educkui_widget_pick_list:update({filter_char, <<"a">>}, S0),
    ?assertEqual(<<"a">>, maps:get(filter, S1)),
    %% Both apple and banana contain 'a'; cherry does not.
    Filtered = filter_items(S1),
    ?assertEqual([{0, <<"apple">>}, {1, <<"banana">>}], Filtered).

navigation_and_select_test() ->
    S0 = educkui_widget_pick_list:init([{items, [<<"apple">>, <<"banana">>, <<"cherry">>]}]),
    {S1, []} = educkui_widget_pick_list:update({filter_char, <<"a">>}, S0),
    {S2, []} = educkui_widget_pick_list:update(down, S1),
    ?assertEqual(1, maps:get(highlight, S2)),
    {S3, []} = educkui_widget_pick_list:update(select, S2),
    ?assertEqual(1, maps:get(selected, S3)),
    ?assertEqual(<<>>, maps:get(filter, S3)).

filter_backspace_test() ->
    S0 = educkui_widget_pick_list:init([{items, [<<"apple">>, <<"banana">>]}]),
    {S1, []} = educkui_widget_pick_list:update({filter_char, <<"ab">>}, S0),
    {S2, []} = educkui_widget_pick_list:update(filter_backspace, S1),
    ?assertEqual(<<"a">>, maps:get(filter, S2)).

focus_test() ->
    S0 = educkui_widget_pick_list:init([{items, [<<"a">>]}]),
    {S1, []} = educkui_widget_pick_list:update(focus_gained, S0),
    ?assertEqual(true, maps:get(focused, S1)),
    {S2, []} = educkui_widget_pick_list:update(focus_lost, S1),
    ?assertEqual(false, maps:get(focused, S2)).

view_unfocused_test() ->
    S = educkui_widget_pick_list:init([{items, [<<"apple">>]}, {prompt, <<"F: ">>}]),
    Node = educkui_widget_pick_list:view(S),
    ?assertEqual(stack, Node#dui_node.type),
    ?assertEqual(1, length(Node#dui_node.children)).

view_focused_shows_filtered_test() ->
    S0 = educkui_widget_pick_list:init([{items, [<<"apple">>, <<"banana">>, <<"cherry">>]}]),
    {S1, []} = educkui_widget_pick_list:update(focus_gained, S0),
    {S2, []} = educkui_widget_pick_list:update({filter_char, <<"a">>}, S1),
    Node = educkui_widget_pick_list:view(S2),
    %% Header + 2 filtered items.
    ?assertEqual(3, length(Node#dui_node.children)).

filter_items(S) ->
    Items = maps:get(items, S),
    Filter = string:lowercase(maps:get(filter, S)),
    [{I, Item}
     || {I, Item} <- lists:zip(lists:seq(0, length(Items) - 1), Items),
        Filter =:= <<>> orelse
        string:find(string:lowercase(Item), Filter) =/= nomatch].
