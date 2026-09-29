-module(educkui_render_node_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

empty_test() ->
    Node = educkui_render_node:empty(),
    ?assertEqual(empty, Node#dui_node.type),
    ?assert(educkui_render_node:is_empty(Node)).

text_test() ->
    Node = educkui_render_node:text(<<"Hello">>),
    ?assertEqual(text, Node#dui_node.type),
    ?assertEqual(<<"Hello">>, Node#dui_node.content),
    ?assertEqual(undefined, Node#dui_node.style).

styled_text_test() ->
    Style = educkui_style:from([{fg, red}]),
    Node = educkui_render_node:text(<<"Hi">>, Style),
    ?assertEqual(red, educkui_style:fg(Node#dui_node.style)).

box_test() ->
    Child = educkui_render_node:text(<<"A">>),
    Node = educkui_render_node:box([Child], [{width, 10}, {height, 5}]),
    ?assertEqual(box, Node#dui_node.type),
    ?assertEqual(10, Node#dui_node.width),
    ?assertEqual(5, Node#dui_node.height),
    ?assertEqual(1, educkui_render_node:child_count(Node)).

stack_test() ->
    Node = educkui_render_node:stack(horizontal,
        [educkui_render_node:text(<<"L">>), educkui_render_node:text(<<"R">>)]),
    ?assertEqual(stack, Node#dui_node.type),
    ?assertEqual(horizontal, Node#dui_node.direction),
    ?assertEqual(2, educkui_render_node:child_count(Node)).

cells_test() ->
    Cell = educkui_cell:new(<<"X">>),
    Node = educkui_render_node:cells([{0, 0, Cell}]),
    ?assertEqual(cells, Node#dui_node.type),
    ?assertEqual([{0, 0, Cell}], Node#dui_node.cells).

styled_test() ->
    Style = educkui_style:from([{bg, blue}]),
    Node = educkui_render_node:styled(educkui_render_node:text(<<"A">>), Style),
    ?assertEqual(box, Node#dui_node.type),
    ?assertEqual(1, educkui_render_node:child_count(Node)).

width_height_test() ->
    Node0 = educkui_render_node:empty(),
    Node1 = educkui_render_node:width(Node0, 20),
    ?assertEqual(20, Node1#dui_node.width),
    Node2 = educkui_render_node:height(Node1, 10),
    ?assertEqual(10, Node2#dui_node.height).
