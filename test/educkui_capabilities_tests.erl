-module(educkui_capabilities_tests).

-include_lib("eunit/include/eunit.hrl").

color_depth_truecolor_test() ->
    os:putenv("COLORTERM", "truecolor"),
    Result = educkui_capabilities:color_depth(),
    os:unsetenv("COLORTERM"),
    ?assertEqual(true_color, Result).

color_depth_256_test() ->
    os:unsetenv("COLORTERM"),
    os:putenv("TERM", "xterm-256color"),
    Result = educkui_capabilities:color_depth(),
    os:unsetenv("TERM"),
    ?assertEqual(color_256, Result).

color_depth_16_test() ->
    os:unsetenv("COLORTERM"),
    os:putenv("TERM", "xterm"),
    Result = educkui_capabilities:color_depth(),
    os:unsetenv("TERM"),
    ?assertEqual(color_16, Result).

detect_test() ->
    Cap = educkui_capabilities:detect(),
    ?assert(is_map(Cap)),
    ?assert(lists:member(maps:get(colors, Cap),
                         [true_color, color_256, color_16, monochrome])),
    ?assert(is_boolean(maps:get(unicode, Cap))),
    ?assert(is_boolean(maps:get(terminal, Cap))).

is_tty_returns_boolean_test() ->
    ?assert(is_boolean(educkui_capabilities:is_tty())).
