-module(educkui_widget_tree_view_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

tree() ->
    [{a, <<"A">>, [{a1, <<"A1">>, []}, {a2, <<"A2">>, []}]},
     {b, <<"B">>, []}].

init_test() ->
    S = educkui_widget_tree_view:init([{items, tree()}]),
    ?assertEqual(a, maps:get(selected, S)),
    ?assertEqual([], maps:get(expanded, S)).

expand_collapse_test() ->
    S0 = educkui_widget_tree_view:init([{items, tree()}]),
    {S1, []} = educkui_widget_tree_view:update(expand, S0),
    ?assertEqual([a], maps:get(expanded, S1)),
    {S2, []} = educkui_widget_tree_view:update(collapse, S1),
    ?assertEqual([], maps:get(expanded, S2)).

toggle_test() ->
    S0 = educkui_widget_tree_view:init([{items, tree()}]),
    {S1, []} = educkui_widget_tree_view:update(toggle, S0),
    ?assertEqual([a], maps:get(expanded, S1)),
    {S2, []} = educkui_widget_tree_view:update(toggle, S1),
    ?assertEqual([], maps:get(expanded, S2)).

selection_moves_test() ->
    S0 = educkui_widget_tree_view:init([{items, tree()}]),
    {S1, []} = educkui_widget_tree_view:update(expand, S0),
    {S2, []} = educkui_widget_tree_view:update(down, S1),
    %% after expanding a: visible = [a, a1, a2, b]; down from a -> a1
    ?assertEqual(a1, maps:get(selected, S2)),
    {S3, []} = educkui_widget_tree_view:update(down, S2),
    ?assertEqual(a2, maps:get(selected, S3)),
    {S4, []} = educkui_widget_tree_view:update(down, S3),
    ?assertEqual(b, maps:get(selected, S4)).

view_test() ->
    S = educkui_widget_tree_view:init([{items, tree()}]),
    Node = educkui_widget_tree_view:view(S),
    %% collapsed: only roots visible
    ?assertEqual(2, length(Node#dui_node.children)).
