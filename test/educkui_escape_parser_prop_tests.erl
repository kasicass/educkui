%% @doc Property-style tests for educkui_escape_parser.
%%
%% These are randomized checks with a fixed seed (no external PropEr
%% dependency). They verify that the parser is total over arbitrary bytes and
%% that printable input round-trips byte-for-byte.
-module(educkui_escape_parser_prop_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

parse_total_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> parse_total_case() end,
        lists:seq(1, 500)).

parse_total_case() ->
    Bin = educkui_prop_utils:rand_binary(),
    {Events, Remaining} = educkui_escape_parser:parse(Bin),
    ?assert(suffix_of(Remaining, Bin)),
    lists:foreach(
        fun(E) -> ?assert(is_record(E, dui_event)) end,
        Events).

printable_roundtrip_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> printable_roundtrip_case() end,
        lists:seq(1, 300)).

printable_roundtrip_case() ->
    Bin = printable_binary(),
    {Events, Remaining} = educkui_escape_parser:parse(Bin),
    ?assertEqual(<<>>, Remaining),
    ?assertEqual(byte_size(Bin), length(Events)),
    lists:foreach(
        fun({Byte, Event}) ->
            ?assertEqual(key, Event#dui_event.type),
            ?assertEqual(<<Byte>>, Event#dui_event.key),
            ?assertEqual(<<Byte>>, Event#dui_event.char)
        end,
        lists:zip(binary_to_list(Bin), Events)).

escape_order_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> escape_order_case() end,
        lists:seq(1, 100)).

escape_order_case() ->
    Pairs = [{<<27, "[A">>, up},
             {<<27, "[B">>, down},
             {<<27, "[C">>, right},
             {<<27, "[D">>, left},
             {<<27, "[H">>, home},
             {<<27, "[F">>, 'end'},
             {<<27, "[5~">>, page_up},
             {<<27, "[6~">>, page_down},
             {<<27, "[3~">>, delete}],
    Shuffled = educkui_prop_utils:rand_shuffle(Pairs),
    Bin = iolist_to_binary([Seq || {Seq, _} <- Shuffled]),
    {Events, Remaining} = educkui_escape_parser:parse(Bin),
    ?assertEqual(<<>>, Remaining),
    ?assertEqual([Key || {_, Key} <- Shuffled],
                 [Event#dui_event.key || Event <- Events]).

%% ---------------------------------------------------------------------------
%% Internal helpers
%% ---------------------------------------------------------------------------

-spec printable_binary() -> binary().
printable_binary() ->
    list_to_binary([educkui_prop_utils:rand_int(32, 126)
                    || _ <- lists:seq(1, educkui_prop_utils:rand_int(0, 64))]).

-spec suffix_of(binary(), binary()) -> boolean().
suffix_of(Remaining, Input) ->
    LS = byte_size(Remaining),
    LI = byte_size(Input),
    LS =< LI andalso binary:part(Input, LI - LS, LS) =:= Remaining.
