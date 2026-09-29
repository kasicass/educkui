-module(educkui_focus_tests).

-include_lib("eunit/include/eunit.hrl").

new_and_current_test() ->
    F = educkui_focus:new(),
    ?assertEqual(undefined, educkui_focus:current(F)).

focus_blur_test() ->
    F0 = educkui_focus:new(),
    F1 = educkui_focus:focus(F0, a),
    ?assertEqual(a, educkui_focus:current(F1)),
    F2 = educkui_focus:focus(F1, b),
    ?assertEqual(b, educkui_focus:current(F2)),
    F3 = educkui_focus:blur(F2),
    ?assertEqual(a, educkui_focus:current(F3)).

next_prev_test() ->
    F = educkui_focus:focus(educkui_focus:new(), b),
    ?assertEqual([c], educkui_focus:next(F, [a, b, c])),
    ?assertEqual([a], educkui_focus:prev(F, [a, b, c])),
    %% Wrap around.
    F2 = educkui_focus:focus(educkui_focus:new(), c),
    ?assertEqual([a], educkui_focus:next(F2, [a, b, c])),
    F3 = educkui_focus:focus(educkui_focus:new(), a),
    ?assertEqual([c], educkui_focus:prev(F3, [a, b, c])).

empty_ids_test() ->
    F = educkui_focus:focus(educkui_focus:new(), a),
    ?assertEqual(F, educkui_focus:next(F, [])),
    ?assertEqual(F, educkui_focus:prev(F, [])).

index_of_test() ->
    ?assertEqual(2, educkui_focus:index_of(b, [a, b, c])),
    ?assertEqual(undefined, educkui_focus:index_of(z, [a, b, c])).
