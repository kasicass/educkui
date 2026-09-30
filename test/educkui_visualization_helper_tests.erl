-module(educkui_visualization_helper_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

style_from_prop_test() ->
    ?assertEqual(undefined,
                 educkui_visualization_helper:style_from_prop(undefined)),
    Style = educkui_style:from([{fg, red}]),
    ?assertEqual(Style,
                 educkui_visualization_helper:style_from_prop(Style)),
    ?assertMatch(#dui_style{fg = red},
                 educkui_visualization_helper:style_from_prop(#{fg => red})),
    ?assertMatch(#dui_style{fg = red},
                 educkui_visualization_helper:style_from_prop([{fg, red}])).

apply_style_test() ->
    Cell0 = educkui_cell:new(<<"a">>),
    ?assertEqual(Cell0,
                 educkui_visualization_helper:apply_style(Cell0, undefined)),
    Cell1 = educkui_visualization_helper:apply_style(
        Cell0, educkui_style:from([{fg, red}, {bold, true}])),
    ?assertEqual(red, Cell1#dui_cell.fg),
    ?assert(educkui_cell:has_attr(Cell1, bold)).

clamp_test() ->
    ?assertEqual(0, educkui_visualization_helper:clamp(-1, 0, 10)),
    ?assertEqual(10, educkui_visualization_helper:clamp(99, 0, 10)),
    ?assertEqual(5, educkui_visualization_helper:clamp(5, 0, 10)).

zip_short_test() ->
    ?assertEqual([{1, a}, {2, b}],
                 educkui_visualization_helper:zip_short([1, 2, 3], [a, b])).

sample_series_test() ->
    ?assertEqual([], educkui_visualization_helper:sample_series([], 5)),
    ?assertEqual([1, 2, 3],
                 educkui_visualization_helper:sample_series([1, 2, 3], 5)),
    ?assertEqual(4, length(educkui_visualization_helper:sample_series(
                         [1, 2, 3, 4, 5, 6], 4))).

ratio_test() ->
    ?assertEqual(0.5, educkui_visualization_helper:ratio(5, 5, 5)),
    ?assertEqual(0.0, educkui_visualization_helper:ratio(0, 0, 10)),
    ?assertEqual(1.0, educkui_visualization_helper:ratio(10, 0, 10)).
