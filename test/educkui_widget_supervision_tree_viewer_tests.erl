-module(educkui_widget_supervision_tree_viewer_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_test() ->
    Tree = [{<<"root">>, [{<<"worker1">>, []}, {<<"worker2">>, []}]}],
    Node = educkui_widget_supervision_tree_viewer:render(
        #{tree => Tree}, #dui_rect{width = 20, height = 5}),
    ?assertEqual(stack, Node#dui_node.type),
    ?assertEqual(3, length(Node#dui_node.children)).

indentation_test() ->
    Tree = [{<<"root">>, [{<<"child">>, []}]}],
    Node = educkui_widget_supervision_tree_viewer:render(
        #{tree => Tree}, #dui_rect{width = 20, height = 5}),
    [Root, Child] = Node#dui_node.children,
    ?assertEqual(<<"root">>, Root#dui_node.content),
    ?assertEqual(<<"  child">>, Child#dui_node.content).
