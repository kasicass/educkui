-module(educkui_terminal_size_tests).

-include_lib("eunit/include/eunit.hrl").

default_test() ->
    ?assertEqual({24, 80}, educkui_terminal_size:default()).

from_io_ok_test() ->
    ?assertEqual({ok, {30, 100}},
                 educkui_terminal_size:from_io({ok, 30}, {ok, 100})).

from_io_env_fallback_test() ->
    os:putenv("COLUMNS", "120"),
    os:putenv("LINES", "50"),
    Result = educkui_terminal_size:from_io({error, enotsup}, {error, enotsup}),
    os:unsetenv("COLUMNS"),
    os:unsetenv("LINES"),
    ?assertEqual({ok, {50, 120}}, Result).

from_io_bad_env_test() ->
    os:putenv("COLUMNS", "bad"),
    os:putenv("LINES", "-5"),
    Result = educkui_terminal_size:from_io({error, enotsup}, {error, enotsup}),
    os:unsetenv("COLUMNS"),
    os:unsetenv("LINES"),
    ?assertEqual(error, Result).

detect_returns_ok_test() ->
    {ok, {Rows, Cols}} = educkui_terminal_size:detect(),
    ?assert(Rows > 0),
    ?assert(Cols > 0).
