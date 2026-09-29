-module(educkui_widget_split_pane_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

children() ->
    [educkui_render_node:text(<<"left">>),
     educkui_render_node:text(<<"right">>)].

init_test() ->
    S = educkui_widget_split_pane:init([{children, children()}, {split, 7}]),
    ?assertEqual(horizontal, maps:get(direction, S)),
    ?assertEqual(7, maps:get(split, S)).

adjust_split_test() ->
    S0 = educkui_widget_split_pane:init([{children, children()}, {split, 7}]),
    {S1, []} = educkui_widget_split_pane:update(split_inc, S0),
    ?assertEqual(8, maps:get(split, S1)),
    {S2, []} = educkui_widget_split_pane:update(split_dec, S1),
    ?assertEqual(7, maps:get(split, S2)),
    %% clamped at 1
    S3 = educkui_widget_split_pane:init([{children, children()}, {split, 1}]),
    {S4, []} = educkui_widget_split_pane:update(split_dec, S3),
    ?assertEqual(1, maps:get(split, S4)).

horizontal_view_test() ->
    S = educkui_widget_split_pane:init([{children, children()}, {split, 7}]),
    Node = educkui_widget_split_pane:view(S),
    ?assertEqual(stack, Node#dui_node.type),
    ?assertEqual(horizontal, Node#dui_node.direction),
    [First, Second] = Node#dui_node.children,
    ?assertEqual(7, First#dui_node.width),
    ?assertEqual(auto, Second#dui_node.width).

vertical_view_test() ->
    S = educkui_widget_split_pane:init([{direction, vertical}, {children, children()}, {split, 5}]),
    Node = educkui_widget_split_pane:view(S),
    ?assertEqual(vertical, Node#dui_node.direction),
    [First, Second] = Node#dui_node.children,
    ?assertEqual(5, First#dui_node.height),
    ?assertEqual(auto, Second#dui_node.height).
