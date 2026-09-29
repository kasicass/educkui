-module(educkui_sgr_tests).

-include_lib("eunit/include/eunit.hrl").

color_param_test() ->
    ?assertEqual("31", educkui_sgr:color_param(fg, red)),
    ?assertEqual("44", educkui_sgr:color_param(bg, blue)),
    ?assertEqual("39", educkui_sgr:color_param(fg, default)),
    ?assertEqual("49", educkui_sgr:color_param(bg, default)),
    ?assertEqual("38;5;196", educkui_sgr:color_param(fg, 196)),
    ?assertEqual("48;5;21", educkui_sgr:color_param(bg, 21)),
    ?assertEqual("38;2;255;128;0", educkui_sgr:color_param(fg, {255, 128, 0})),
    ?assertEqual("48;2;1;2;3", educkui_sgr:color_param(bg, {1, 2, 3})),
    ?assertEqual(undefined, educkui_sgr:color_param(fg, not_a_color)),
    ?assertEqual(undefined, educkui_sgr:color_param(bg, 300)).

attr_param_test() ->
    ?assertEqual("1", educkui_sgr:attr_param(bold)),
    ?assertEqual("4", educkui_sgr:attr_param(underline)),
    ?assertEqual(undefined, educkui_sgr:attr_param(not_an_attr)).

attr_off_param_test() ->
    ?assertEqual("22", educkui_sgr:attr_off_param(bold)),
    ?assertEqual("24", educkui_sgr:attr_off_param(underline)),
    ?assertEqual(undefined, educkui_sgr:attr_off_param(not_an_attr)).

build_sequence_test() ->
    ?assertEqual(<<>>, iolist_to_binary(educkui_sgr:build_sequence([]))),
    ?assertEqual(<<"\e[1;31m">>,
                 iolist_to_binary(educkui_sgr:build_sequence(["1", "31"]))),
    ?assertEqual(<<"\e[31m">>,
                 iolist_to_binary(educkui_sgr:build_sequence([undefined, "31"]))),
    ?assertEqual(<<>>, iolist_to_binary(educkui_sgr:build_sequence([undefined]))).

sequence_mode_test() ->
    ?assertEqual(<<"\e[31m">>, iolist_to_binary(educkui_sgr:color_sequence(fg, red))),
    ?assertEqual(<<"\e[39m">>, iolist_to_binary(educkui_sgr:color_sequence(fg, default))),
    ?assertEqual(<<>>, iolist_to_binary(educkui_sgr:color_sequence(fg, bogus))),
    ?assertEqual(<<"\e[1m">>, iolist_to_binary(educkui_sgr:attr_sequence(bold))),
    ?assertEqual(<<>>, iolist_to_binary(educkui_sgr:attr_sequence(bogus))),
    ?assertEqual(<<"\e[0m">>, iolist_to_binary(educkui_sgr:reset())).

introspection_test() ->
    ?assertEqual(16, length(educkui_sgr:named_colors())),
    ?assert(lists:member(red, educkui_sgr:named_colors())),
    ?assertEqual(8, length(educkui_sgr:supported_attrs())),
    ?assert(lists:member(bold, educkui_sgr:supported_attrs())).
