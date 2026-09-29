-module(educkui_widget_log_viewer_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

last_lines_test() ->
    Node = educkui_widget_log_viewer:render(
        #{lines => [<<"a">>, <<"b">>, <<"c">>, <<"d">>]},
        #dui_rect{width = 10, height = 2}),
    ?assertEqual(stack, Node#dui_node.type),
    [Last, Prev] = Node#dui_node.children,
    ?assertEqual(<<"c">>, Last#dui_node.content),
    ?assertEqual(<<"d">>, Prev#dui_node.content).

empty_test() ->
    Node = educkui_widget_log_viewer:render(
        #{lines => []}, #dui_rect{width = 10, height = 3}),
    ?assertEqual(0, length(Node#dui_node.children)).
