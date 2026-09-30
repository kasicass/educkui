-module(educkui_layout_constraint_tests).

-include_lib("eunit/include/eunit.hrl").

constructors_test() ->
    ?assertEqual({fixed, 3}, educkui_layout_constraint:fixed(3)),
    ?assertEqual({min, 2}, educkui_layout_constraint:min(2)),
    ?assertEqual({max, 5}, educkui_layout_constraint:max(5)),
    ?assertEqual({flex, 1}, educkui_layout_constraint:flex(1)).
