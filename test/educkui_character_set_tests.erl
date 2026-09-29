-module(educkui_character_set_tests).

-include_lib("eunit/include/eunit.hrl").

unicode_border_test() ->
    ?assertEqual(<<"┌"/utf8>>, educkui_character_set:get(unicode, top_left)),
    ?assertEqual(<<"─"/utf8>>, educkui_character_set:get(unicode, horizontal)),
    ?assertEqual(<<"│"/utf8>>, educkui_character_set:get(unicode, vertical)).

ascii_border_test() ->
    ?assertEqual(<<"+">>, educkui_character_set:get(ascii, top_left)),
    ?assertEqual(<<"-">>, educkui_character_set:get(ascii, horizontal)),
    ?assertEqual(<<"|">>, educkui_character_set:get(ascii, vertical)).
