-module(educkui_term_utils_tests).

-include_lib("eunit/include/eunit.hrl").

mouse_off_test() ->
    ?assertEqual(<<"\e[?1006l\e[?1003l\e[?1002l\e[?1000l">>,
                 educkui_term_utils:mouse_off()).
