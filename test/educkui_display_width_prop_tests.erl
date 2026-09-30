%% @doc Property-style tests for educkui_display_width.
%%
%% Randomized checks with a fixed seed (no external PropEr dependency).
-module(educkui_display_width_prop_tests).

-include_lib("eunit/include/eunit.hrl").

string_width_self_consistent_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> string_width_self_consistent_case() end,
        lists:seq(1, 200)).

string_width_self_consistent_case() ->
    Text = random_text(),
    Sum = lists:sum(
        [educkui_display_width:width(unicode:characters_to_binary([G]))
         || G <- string:to_graphemes(Text)]),
    ?assertEqual(Sum, educkui_display_width:string_width(Text)).

truncate_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> truncate_case() end,
        lists:seq(1, 200)).

truncate_case() ->
    Text = random_text(),
    Max = educkui_prop_utils:rand_int(0, 20),
    {Truncated, Width} = educkui_display_width:truncate(Text, Max),
    ?assert(Width =< Max),
    ?assertEqual(Width, educkui_display_width:string_width(Truncated)).

%% ---------------------------------------------------------------------------
%% Internal helpers
%% ---------------------------------------------------------------------------

-spec random_text() -> binary().
random_text() ->
    Graphemes = [<<"a">>, <<"你">>, <<" ">>, <<"e">>, <<"😀"/utf8>>],
    list_to_binary([educkui_prop_utils:rand_choice(Graphemes)
                    || _ <- lists:seq(1, educkui_prop_utils:rand_int(0, 20))]).
