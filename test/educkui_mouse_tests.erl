-module(educkui_mouse_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

point_in_rect_test() ->
    Rect = #dui_rect{x = 10, y = 5, width = 20, height = 10},
    ?assert(educkui_mouse:point_in_rect(10, 5, Rect)),
    ?assert(educkui_mouse:point_in_rect(29, 14, Rect)),
    ?assertNot(educkui_mouse:point_in_rect(30, 5, Rect)),
    ?assertNot(educkui_mouse:point_in_rect(10, 15, Rect)),
    ?assertNot(educkui_mouse:point_in_rect(9, 5, Rect)).

find_target_test() ->
    R1 = #dui_rect{x = 0, y = 0, width = 10, height = 10},
    R2 = #dui_rect{x = 10, y = 0, width = 10, height = 10},
    Targets = [{a, R1}, {b, R2}],
    ?assertEqual({ok, a}, educkui_mouse:find_target(5, 5, Targets)),
    ?assertEqual({ok, b}, educkui_mouse:find_target(15, 5, Targets)),
    ?assertEqual(none, educkui_mouse:find_target(100, 100, Targets)).
