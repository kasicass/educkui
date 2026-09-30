%% @doc Deterministic random helpers for property-style tests.
%%
%% Uses a fixed seed so test failures are reproducible. Kept free of external
%% dependencies (no PropEr) to preserve the zero-dependency CI setup.
-module(educkui_prop_utils).

-export([seed/0, rand_int/2, rand_binary/0, rand_binary/1, rand_choice/1,
         rand_shuffle/1]).

-spec seed() -> ok.
seed() ->
    _ = rand:seed(exsplus, {1337, 424242, 999999}),
    ok.

-spec rand_int(integer(), integer()) -> integer().
rand_int(Lo, Hi) ->
    Lo + rand:uniform(Hi - Lo + 1) - 1.

-spec rand_binary() -> binary().
rand_binary() ->
    rand_binary(rand_int(0, 64)).

-spec rand_binary(non_neg_integer()) -> binary().
rand_binary(MaxLen) ->
    Len = rand_int(0, MaxLen),
    list_to_binary([rand:uniform(256) - 1 || _ <- lists:seq(1, Len)]).

-spec rand_choice([term()]) -> term().
rand_choice([]) -> undefined;
rand_choice(List) ->
    lists:nth(rand:uniform(length(List)), List).

-spec rand_shuffle([term()]) -> [term()].
rand_shuffle(List) ->
    shuffle(List, []).

-spec shuffle([term()], [term()]) -> [term()].
shuffle([], Acc) ->
    Acc;
shuffle(List, Acc) ->
    Idx = rand:uniform(length(List)),
    Elem = lists:nth(Idx, List),
    shuffle(lists:delete(Elem, List), [Elem | Acc]).
