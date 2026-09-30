%% @doc Property-style tests for educkui_layout_solver.
%%
%% Randomized checks with a fixed seed (no external PropEr dependency).
%% Verifies solve/2 length/non-negativity and per-constraint invariants, plus
%% align/3 offset invariants.
-module(educkui_layout_solver_prop_tests).

-include_lib("eunit/include/eunit.hrl").

solve_invariants_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> solve_invariants_case() end,
        lists:seq(1, 300)).

solve_invariants_case() ->
    Total = educkui_prop_utils:rand_int(0, 50),
    Constraints = [random_constraint()
                   || _ <- lists:seq(1, educkui_prop_utils:rand_int(0, 20))],
    Sizes = educkui_layout_solver:solve(Total, Constraints),
    ?assertEqual(length(Constraints), length(Sizes)),
    lists:foreach(fun(S) -> ?assert(S >= 0) end, Sizes),
    lists:foreach(
        fun({Constraint, Size}) -> check_constraint(Constraint, Size) end,
        lists:zip(Constraints, Sizes)).

align_invariants_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> align_invariants_case() end,
        lists:seq(1, 300)).

align_invariants_case() ->
    Total = educkui_prop_utils:rand_int(0, 30),
    Sizes = [educkui_prop_utils:rand_int(0, 10)
             || _ <- lists:seq(1, educkui_prop_utils:rand_int(1, 8))],
    Align = educkui_prop_utils:rand_choice([start, center, 'end', space_between]),
    Offsets = educkui_layout_solver:align(Align, Total, Sizes),
    ?assertEqual(length(Sizes), length(Offsets)),
    lists:foreach(fun(O) -> ?assert(O >= 0) end, Offsets),
    assert_nondecreasing(Offsets).

%% ---------------------------------------------------------------------------
%% Internal helpers
%% ---------------------------------------------------------------------------

-spec random_constraint() -> educkui_layout_constraint:constraint().
random_constraint() ->
    educkui_prop_utils:rand_choice(
        [{fixed, educkui_prop_utils:rand_int(0, 10)},
         {min, educkui_prop_utils:rand_int(0, 10)},
         {max, educkui_prop_utils:rand_int(0, 10)},
         {flex, educkui_prop_utils:rand_int(1, 3)}]).

-spec check_constraint(educkui_layout_constraint:constraint(),
                       non_neg_integer()) -> ok.
check_constraint({fixed, N}, Size) -> ?assertEqual(N, Size);
check_constraint({min, N}, Size) -> ?assert(Size >= N);
check_constraint({max, N}, Size) -> ?assert(Size =< N);
check_constraint({flex, _}, _Size) -> ok.

-spec assert_nondecreasing([integer()]) -> ok.
assert_nondecreasing([]) -> ok;
assert_nondecreasing([_]) -> ok;
assert_nondecreasing([A, B | Rest]) ->
    ?assert(A =< B),
    assert_nondecreasing([B | Rest]).
