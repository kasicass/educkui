-module(educkui_widget_menu_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

items() ->
    [{file, <<"File">>, [
        {new, <<"New">>, []},
        {open, <<"Open">>, []}
    ]},
     {edit, <<"Edit">>, [
        {copy, <<"Copy">>, []}
    ]}].

navigation_test() ->
    S0 = educkui_widget_menu:init([{items, items()}]),
    {S1, []} = educkui_widget_menu:update(down, S0),
    ?assertEqual(1, maps:get(selected, S1)),
    %% Enter on "File" opens its submenu.
    {S2, []} = educkui_widget_menu:update(activate, S0),
    ?assertEqual([0], maps:get(path, S2)),
    ?assertEqual(0, maps:get(selected, S2)),
    %% Back returns to the root level.
    {S3, []} = educkui_widget_menu:update(back, S2),
    ?assertEqual([], maps:get(path, S3)).

activate_leaf_test() ->
    S0 = educkui_widget_menu:init([{items, items()}]),
    {S1, []} = educkui_widget_menu:update(activate, S0),
    {S2, []} = educkui_widget_menu:update(down, S1),
    {S3, [{parent, {menu_activate, open}}]} =
        educkui_widget_menu:update(activate, S2),
    ?assertEqual([0], maps:get(path, S3)).

view_test() ->
    S = educkui_widget_menu:init([{items, items()}]),
    Node = educkui_widget_menu:view(S),
    ?assertEqual(stack, Node#dui_node.type),
    ?assertEqual(2, length(Node#dui_node.children)).
