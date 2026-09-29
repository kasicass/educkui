-module(educkui_layout_solver_tests).

-include_lib("eunit/include/eunit.hrl").

fixed_test() ->
    ?assertEqual([10, 20],
                 educkui_layout_solver:solve(30,
                     [educkui_layout_constraint:fixed(10),
                      educkui_layout_constraint:fixed(20)])).

flex_distribution_test() ->
    ?assertEqual([50, 50],
                 educkui_layout_solver:solve(100,
                     [educkui_layout_constraint:flex(1),
                      educkui_layout_constraint:flex(1)])).

weighted_flex_test() ->
    ?assertEqual([25, 75],
                 educkui_layout_solver:solve(100,
                     [educkui_layout_constraint:flex(1),
                      educkui_layout_constraint:flex(3)])).

mixed_test() ->
    ?assertEqual([10, 45, 45],
                 educkui_layout_solver:solve(100,
                     [educkui_layout_constraint:fixed(10),
                      educkui_layout_constraint:flex(1),
                      educkui_layout_constraint:flex(1)])).

max_constraint_test() ->
    ?assertEqual([30, 70],
                 educkui_layout_solver:solve(100,
                     [educkui_layout_constraint:max(30),
                      educkui_layout_constraint:flex(1)])).

align_start_test() ->
    ?assertEqual([0, 10], educkui_layout_solver:align(start, 100, [10, 20])).

align_center_test() ->
    ?assertEqual([35, 45], educkui_layout_solver:align(center, 100, [10, 20])).

align_end_test() ->
    ?assertEqual([70, 80], educkui_layout_solver:align('end', 100, [10, 20])).

align_space_between_test() ->
    ?assertEqual([0, 80], educkui_layout_solver:align(space_between, 100, [10, 20])).
