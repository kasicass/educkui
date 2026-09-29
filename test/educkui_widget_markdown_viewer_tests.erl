-module(educkui_widget_markdown_viewer_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_md(Text) ->
    educkui_widget_markdown_viewer:render(#{text => Text},
        #dui_rect{width = 40, height = 20}).

heading_test() ->
    Node = render_md(<<"# Title">>),
    [Heading] = Node#dui_node.children,
    ?assertEqual(<<"Title">>, Heading#dui_node.content),
    ?assertEqual(true, educkui_style:has_attr(Heading#dui_node.style, bold)).

bullet_test() ->
    Node = render_md(<<"- item">>),
    [Bullet] = Node#dui_node.children,
    ?assertEqual(horizontal, Bullet#dui_node.direction).

bold_inline_test() ->
    Node = render_md(<<"Hello **world**">>),
    [Inline] = Node#dui_node.children,
    ?assertEqual(horizontal, Inline#dui_node.direction),
    [Plain, Bold] = Inline#dui_node.children,
    ?assertEqual(<<"Hello ">>, Plain#dui_node.content),
    ?assertEqual(<<"world">>, Bold#dui_node.content),
    ?assertEqual(true, educkui_style:has_attr(Bold#dui_node.style, bold)).

plain_test() ->
    Node = render_md(<<"just text">>),
    [Line] = Node#dui_node.children,
    ?assertEqual(horizontal, Line#dui_node.direction).
