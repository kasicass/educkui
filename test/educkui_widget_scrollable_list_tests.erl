-module(educkui_widget_scrollable_list_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

init_test() ->
    S = educkui_widget_scrollable_list:init([{items, [<<"a">>, <<"b">>]},
                                             {height, 5}]),
    ?assertEqual(5, maps:get(height, S)),
    ?assertEqual(0, maps:get(selected, S)),
    ?assertEqual(0, maps:get(offset, S)).

navigation_test() ->
    S0 = educkui_widget_scrollable_list:init([{items, [<<"a">>, <<"b">>, <<"c">>]},
                                              {height, 2}]),
    {S1, []} = educkui_widget_scrollable_list:update(down, S0),
    ?assertEqual(1, maps:get(selected, S1)),
    ?assertEqual(0, maps:get(offset, S1)),
    {S2, []} = educkui_widget_scrollable_list:update(down, S1),
    ?assertEqual(2, maps:get(selected, S2)),
    ?assertEqual(1, maps:get(offset, S2)),
    {S3, []} = educkui_widget_scrollable_list:update(home, S2),
    ?assertEqual(0, maps:get(selected, S3)),
    ?assertEqual(0, maps:get(offset, S3)).

page_down_test() ->
    S0 = educkui_widget_scrollable_list:init([{items, [<<"a">>, <<"b">>, <<"c">>,
                                                      <<"d">>, <<"e">>]},
                                              {height, 2}]),
    {S1, []} = educkui_widget_scrollable_list:update(page_down, S0),
    ?assertEqual(2, maps:get(selected, S1)),
    {S2, []} = educkui_widget_scrollable_list:update('end', S1),
    ?assertEqual(4, maps:get(selected, S2)),
    ?assertEqual(3, maps:get(offset, S2)).

view_test() ->
    S = educkui_widget_scrollable_list:init([{items, [<<"a">>, <<"b">>, <<"c">>]},
                                             {height, 2}]),
    Node = educkui_widget_scrollable_list:view(S),
    ?assertEqual(2, length(Node#dui_node.children)).
