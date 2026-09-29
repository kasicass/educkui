-module(educkui_component_helpers_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

text_box_stack_test() ->
    Node = educkui_component_helpers:stack(vertical, [
        educkui_component_helpers:text(<<"Hello">>),
        educkui_component_helpers:box([educkui_component_helpers:text(<<"X">>)])
    ]),
    ?assertEqual(stack, Node#dui_node.type),
    ?assertEqual(2, educkui_render_node:child_count(Node)).

props_required_test() ->
    Props = #{text => <<"hi">>, count => 5},
    Result = educkui_component_helpers:props(Props, [
        {text, string, [{required, true}]},
        {count, integer, [{default, 0}]}
    ]),
    ?assertEqual(<<"hi">>, maps:get(text, Result)),
    ?assertEqual(5, maps:get(count, Result)).

props_missing_required_test() ->
    ?assertError({missing_required_prop, text},
                 educkui_component_helpers:props(#{},
                     [{text, string, [{required, true}]}])).

props_invalid_type_test() ->
    ?assertError({invalid_prop, count, integer, _},
                 educkui_component_helpers:props(#{count => <<"x">>},
                     [{count, integer, [{required, true}]}])).

merge_styles_test() ->
    S1 = educkui_style:from([{fg, white}]),
    S2 = educkui_style:from([{fg, red}, {bold, true}]),
    Merged = educkui_component_helpers:merge_styles([S1, S2, undefined]),
    ?assertEqual(red, educkui_style:fg(Merged)),
    ?assert(educkui_style:has_attr(Merged, bold)).

compute_size_test() ->
    ?assertEqual({5, 1}, educkui_component_helpers:compute_size(<<"Hello">>)),
    ?assertEqual({6, 2}, educkui_component_helpers:compute_size(<<"Line 1\nLine 2">>)).

compute_node_size_test() ->
    ?assertEqual({5, 1},
                 educkui_component_helpers:compute_node_size(
                     educkui_render_node:text(<<"Hello">>))),
    ?assertEqual({0, 0},
                 educkui_component_helpers:compute_node_size(
                     educkui_render_node:empty())).

fits_in_rect_test() ->
    Rect = #dui_rect{width = 20, height = 10},
    ?assert(educkui_component_helpers:fits_in_rect({10, 5}, Rect)),
    ?assertNot(educkui_component_helpers:fits_in_rect({30, 5}, Rect)).

truncate_text_test() ->
    ?assertEqual(<<"Hello">>, educkui_component_helpers:truncate_text(<<"Hello World">>, 5)),
    ?assertEqual(<<"Hi">>, educkui_component_helpers:truncate_text(<<"Hi">>, 10)).

positioned_cell_test() ->
    {X, Y, Cell} = educkui_component_helpers:positioned_cell(1, 2, <<"A">>),
    ?assertEqual(1, X),
    ?assertEqual(2, Y),
    ?assertEqual(<<"A">>, Cell#dui_cell.char).

positioned_cell_styled_test() ->
    Style = educkui_style:from([{fg, red}, {bold, true}]),
    {_X, _Y, Cell} = educkui_component_helpers:positioned_cell(0, 0, <<"B">>, Style),
    ?assertEqual(red, Cell#dui_cell.fg),
    ?assert(educkui_cell:has_attr(Cell, bold)).
