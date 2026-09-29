-module(educkui_widget_tabs_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

tabs() ->
    [{<<"One">>, educkui_render_node:text(<<"content-1">>)},
     {<<"Two">>, educkui_render_node:text(<<"content-2">>)}].

switch_test() ->
    S0 = educkui_widget_tabs:init([{tabs, tabs()}]),
    ?assertEqual(0, maps:get(active, S0)),
    {S1, []} = educkui_widget_tabs:update(next, S0),
    ?assertEqual(1, maps:get(active, S1)),
    {S2, []} = educkui_widget_tabs:update(prev, S1),
    ?assertEqual(0, maps:get(active, S2)),
    %% wraps around
    {S3, []} = educkui_widget_tabs:update(prev, S0),
    ?assertEqual(1, maps:get(active, S3)).

view_test() ->
    S = educkui_widget_tabs:init([{tabs, tabs()}]),
    Node = educkui_widget_tabs:view(S),
    ?assertEqual(stack, Node#dui_node.type),
    %% header + content
    ?assertEqual(2, length(Node#dui_node.children)).

view_active_content_test() ->
    {S, []} = educkui_widget_tabs:update(next,
        educkui_widget_tabs:init([{tabs, tabs()}])),
    Node = educkui_widget_tabs:view(S),
    [Header, Content] = Node#dui_node.children,
    ?assertEqual(text, Content#dui_node.type),
    ?assertEqual(<<"content-2">>, Content#dui_node.content),
    ?assertEqual(2, length(Header#dui_node.children)).
