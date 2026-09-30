%% @doc Property-style tests for educkui_sgr.
%%
%% Exhaustive/randomized checks over named colors, 256-color indexes, RGB
%% tuples and attributes.
-module(educkui_sgr_prop_tests).

-include_lib("eunit/include/eunit.hrl").

named_color_prop_test() ->
    lists:foreach(
        fun(Color) ->
            lists:foreach(
                fun(Type) ->
                    Param = educkui_sgr:color_param(Type, Color),
                    ?assert(is_list(Param)),
                    ?assert(Param =/= []),
                    Seq = iolist_to_binary(educkui_sgr:color_sequence(Type, Color)),
                    ?assert(binary:match(Seq, list_to_binary(Param)) =/= nomatch)
                end,
                [fg, bg])
        end,
        educkui_sgr:named_colors()).

color_256_prop_test() ->
    lists:foreach(
        fun(N) ->
            ?assertEqual("38;5;" ++ integer_to_list(N),
                         educkui_sgr:color_param(fg, N)),
            ?assertEqual("48;5;" ++ integer_to_list(N),
                         educkui_sgr:color_param(bg, N))
        end,
        lists:seq(0, 255)).

rgb_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) ->
            R = educkui_prop_utils:rand_int(0, 255),
            G = educkui_prop_utils:rand_int(0, 255),
            B = educkui_prop_utils:rand_int(0, 255),
            Expected = "38;2;" ++ integer_to_list(R) ++ ";" ++
                       integer_to_list(G) ++ ";" ++ integer_to_list(B),
            ?assertEqual(Expected, educkui_sgr:color_param(fg, {R, G, B}))
        end,
        lists:seq(1, 50)).

invalid_color_prop_test() ->
    ?assertEqual(undefined, educkui_sgr:color_param(fg, bogus)),
    ?assertEqual(undefined, educkui_sgr:color_param(fg, -1)),
    ?assertEqual(undefined, educkui_sgr:color_param(fg, 256)).

attr_prop_test() ->
    lists:foreach(
        fun(Attr) ->
            ?assert(is_list(educkui_sgr:attr_param(Attr))),
            ?assert(is_list(educkui_sgr:attr_off_param(Attr)))
        end,
        educkui_sgr:supported_attrs()),
    ?assertEqual(undefined, educkui_sgr:attr_param(bogus)).
