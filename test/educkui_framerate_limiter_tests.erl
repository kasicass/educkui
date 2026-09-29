-module(educkui_framerate_limiter_tests).

-include_lib("eunit/include/eunit.hrl").

default_interval_test() ->
    ?assertEqual(16, educkui_framerate_limiter:default_interval()).

first_render_test() ->
    ?assert(educkui_framerate_limiter:should_render(undefined, 16)).

recent_render_test() ->
    Now = educkui_framerate_limiter:monotonic_ms(),
    ?assertNot(educkui_framerate_limiter:should_render(Now, 16)).

elapsed_render_test() ->
    Now = educkui_framerate_limiter:monotonic_ms(),
    ?assert(educkui_framerate_limiter:should_render(Now - 100, 16)).
