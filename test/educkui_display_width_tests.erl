-module(educkui_display_width_tests).

-include_lib("eunit/include/eunit.hrl").

width_test() ->
    ?assertEqual(1, educkui_display_width:width(<<"A">>)),
    ?assertEqual(2, educkui_display_width:width(<<"日"/utf8>>)),
    ?assertEqual(2, educkui_display_width:width(<<"😀"/utf8>>)),
    ?assertEqual(1, educkui_display_width:width(<<"é"/utf8>>)),
    %% Combining acute alone is zero width.
    ?assertEqual(0, educkui_display_width:width(<<16#301/utf8>>)),
    %% Halfwidth katakana is single width.
    ?assertEqual(1, educkui_display_width:width(<<"ｱ"/utf8>>)).

string_width_test() ->
    ?assertEqual(5, educkui_display_width:string_width(<<"Hello">>)),
    ?assertEqual(6, educkui_display_width:string_width(<<"日本語"/utf8>>)),
    ?assertEqual(4, educkui_display_width:string_width(<<"Café"/utf8>>)).

double_width_test() ->
    ?assert(educkui_display_width:double_width(<<"日"/utf8>>)),
    ?assertNot(educkui_display_width:double_width(<<"A">>)).

zero_width_test() ->
    ?assert(educkui_display_width:zero_width(<<16#301/utf8>>)),
    ?assertNot(educkui_display_width:zero_width(<<"A">>)).

truncate_test() ->
    ?assertEqual({<<"Hello">>, 5}, educkui_display_width:truncate(<<"Hello World">>, 5)),
    ?assertEqual({<<"日本"/utf8>>, 4},
                 educkui_display_width:truncate(<<"日本語"/utf8>>, 4)),
    ?assertEqual({<<>>, 0}, educkui_display_width:truncate(<<"ABC">>, 0)).
