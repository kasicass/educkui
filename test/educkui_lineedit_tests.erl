-module(educkui_lineedit_tests).

-include_lib("eunit/include/eunit.hrl").

new_empty_test() ->
    LE = educkui_lineedit:new(),
    ?assertEqual(<<>>, educkui_lineedit:value(LE)),
    ?assertEqual(0, educkui_lineedit:cursor(LE)).

new_value_test() ->
    LE = educkui_lineedit:new(<<"ab">>),
    ?assertEqual(<<"ab">>, educkui_lineedit:value(LE)),
    ?assertEqual(2, educkui_lineedit:cursor(LE)),
    ?assertEqual(2, educkui_lineedit:length(LE)).

new_value_cursor_test() ->
    LE = educkui_lineedit:new(<<"ab">>, 1),
    ?assertEqual(1, educkui_lineedit:cursor(LE)),
    ?assertEqual(2, educkui_lineedit:cursor(educkui_lineedit:new(<<"ab">>, 99))).

insert_at_end_test() ->
    LE = educkui_lineedit:insert(<<"X">>, educkui_lineedit:new(<<"ab">>)),
    ?assertEqual(<<"abX">>, educkui_lineedit:value(LE)),
    ?assertEqual(3, educkui_lineedit:cursor(LE)).

insert_in_middle_test() ->
    LE0 = educkui_lineedit:new(<<"ab">>, 1),
    LE1 = educkui_lineedit:insert(<<"X">>, LE0),
    ?assertEqual(<<"aXb">>, educkui_lineedit:value(LE1)),
    ?assertEqual(2, educkui_lineedit:cursor(LE1)).

insert_multi_grapheme_test() ->
    LE = educkui_lineedit:insert(<<"hello">>, educkui_lineedit:new(<<"ab">>, 1)),
    ?assertEqual(<<"ahellob">>, educkui_lineedit:value(LE)),
    ?assertEqual(6, educkui_lineedit:cursor(LE)).

backspace_at_start_is_noop_test() ->
    LE = educkui_lineedit:new(<<>>),
    ?assertEqual(LE, educkui_lineedit:backspace(LE)).

backspace_test() ->
    LE = educkui_lineedit:backspace(educkui_lineedit:new(<<"abc">>)),
    ?assertEqual(<<"ab">>, educkui_lineedit:value(LE)),
    ?assertEqual(2, educkui_lineedit:cursor(LE)).

backspace_grapheme_test() ->
    %% Two wide graphemes; deleting one must not split a codepoint.
    LE0 = educkui_lineedit:new(<<"你好"/utf8>>),
    LE1 = educkui_lineedit:backspace(LE0),
    ?assertEqual(<<"你"/utf8>>, educkui_lineedit:value(LE1)).

delete_at_end_is_noop_test() ->
    LE = educkui_lineedit:new(<<"ab">>),
    ?assertEqual(LE, educkui_lineedit:delete(LE)).

delete_test() ->
    LE0 = educkui_lineedit:new(<<"abc">>, 1),
    LE1 = educkui_lineedit:delete(LE0),
    ?assertEqual(<<"ac">>, educkui_lineedit:value(LE1)),
    ?assertEqual(1, educkui_lineedit:cursor(LE1)).

move_test() ->
    LE0 = educkui_lineedit:new(<<"ab">>),
    ?assertEqual(1, educkui_lineedit:cursor(educkui_lineedit:move(left, LE0))),
    ?assertEqual(2, educkui_lineedit:cursor(educkui_lineedit:move(right, LE0))),
    ?assertEqual(0, educkui_lineedit:cursor(
        educkui_lineedit:move(left, educkui_lineedit:move(left, LE0)))).

home_end_test() ->
    LE = educkui_lineedit:new(<<"abc">>, 1),
    ?assertEqual(0, educkui_lineedit:cursor(educkui_lineedit:home(LE))),
    ?assertEqual(3, educkui_lineedit:cursor(educkui_lineedit:'end'(LE))).

set_value_clamps_cursor_test() ->
    LE0 = educkui_lineedit:new(<<"abcdef">>, 5),
    LE1 = educkui_lineedit:set_value(<<"ab">>, LE0),
    ?assertEqual(<<"ab">>, educkui_lineedit:value(LE1)),
    ?assertEqual(2, educkui_lineedit:cursor(LE1)).

set_cursor_clamps_test() ->
    LE = educkui_lineedit:new(<<"ab">>),
    ?assertEqual(0, educkui_lineedit:cursor(educkui_lineedit:set_cursor(0, LE))),
    ?assertEqual(2, educkui_lineedit:cursor(educkui_lineedit:set_cursor(99, LE))).
