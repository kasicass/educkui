-module(educkui_widget_text_area_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

init_test() ->
    S = educkui_widget_text_area:init([{value, <<"a\nbc">>}]),
    ?assertEqual([<<"a">>, <<"bc">>], maps:get(lines, S)),
    ?assertEqual(1, maps:get(row, S)),
    ?assertEqual(2, maps:get(col, S)).

insert_test() ->
    S0 = educkui_widget_text_area:init([{value, <<"ab">>}]),
    {S1, []} = educkui_widget_text_area:update({insert, <<"X">>}, S0),
    ?assertEqual([<<"abX">>], maps:get(lines, S1)).

newline_test() ->
    S0 = educkui_widget_text_area:init([{value, <<"ab">>}]),
    {S1, []} = educkui_widget_text_area:update(home, S0),
    {S2, []} = educkui_widget_text_area:update(newline, S1),
    ?assertEqual([<<>>, <<"ab">>], maps:get(lines, S2)),
    ?assertEqual(1, maps:get(row, S2)).

backspace_test() ->
    S0 = educkui_widget_text_area:init([{value, <<"abc">>}]),
    {S1, []} = educkui_widget_text_area:update(backspace, S0),
    ?assertEqual([<<"ab">>], maps:get(lines, S1)).

backspace_join_lines_test() ->
    S0 = educkui_widget_text_area:init([{value, <<"a\nb">>}]),
    {S1, []} = educkui_widget_text_area:update(home, S0),
    {S2, []} = educkui_widget_text_area:update(backspace, S1),
    ?assertEqual([<<"ab">>], maps:get(lines, S2)),
    ?assertEqual(0, maps:get(row, S2)).

arrow_movement_test() ->
    S0 = educkui_widget_text_area:init([{value, <<"abc">>}]),
    {S1, []} = educkui_widget_text_area:update(left, S0),
    ?assertEqual(2, maps:get(col, S1)),
    {S2, []} = educkui_widget_text_area:update(home, S1),
    ?assertEqual(0, maps:get(col, S2)),
    {S3, []} = educkui_widget_text_area:update('end', S2),
    ?assertEqual(3, maps:get(col, S3)).
