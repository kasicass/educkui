-module(educkui_escape_parser_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

parse_empty_test() ->
    ?assertEqual({[], <<>>}, educkui_escape_parser:parse(<<>>)).

control_chars_test() ->
    {[Ev], <<>>} = educkui_escape_parser:parse(<<8>>),
    ?assertEqual(backspace, Ev#dui_event.key),
    {[Ev2], <<>>} = educkui_escape_parser:parse(<<9>>),
    ?assertEqual(tab, Ev2#dui_event.key),
    {[Ev3], <<>>} = educkui_escape_parser:parse(<<13>>),
    ?assertEqual(enter, Ev3#dui_event.key),
    {[Ev4], <<>>} = educkui_escape_parser:parse(<<3>>),
    ?assertEqual(<<"c">>, Ev4#dui_event.key),
    ?assertEqual([ctrl], Ev4#dui_event.modifiers).

printable_test() ->
    {[Ev], <<>>} = educkui_escape_parser:parse(<<"a">>),
    ?assertEqual(<<"a">>, Ev#dui_event.key),
    ?assertEqual(<<"a">>, Ev#dui_event.char).

utf8_test() ->
    {[Ev], <<>>} = educkui_escape_parser:parse(<<"日"/utf8>>),
    ?assertEqual(<<"日"/utf8>>, Ev#dui_event.key),
    ?assertEqual(<<"日"/utf8>>, Ev#dui_event.char).

arrows_test() ->
    {[Ev], <<>>} = educkui_escape_parser:parse(<<27, 91, 65>>),
    ?assertEqual(up, Ev#dui_event.key),
    {[Ev2], <<>>} = educkui_escape_parser:parse(<<27, 91, 66>>),
    ?assertEqual(down, Ev2#dui_event.key),
    {[Ev3], <<>>} = educkui_escape_parser:parse(<<27, 91, 67>>),
    ?assertEqual(right, Ev3#dui_event.key),
    {[Ev4], <<>>} = educkui_escape_parser:parse(<<27, 91, 68>>),
    ?assertEqual(left, Ev4#dui_event.key).

tilde_sequences_test() ->
    {[Ev], <<>>} = educkui_escape_parser:parse(<<27, 91, "3~">>),
    ?assertEqual(delete, Ev#dui_event.key),
    {[Ev2], <<>>} = educkui_escape_parser:parse(<<27, 91, "5~">>),
    ?assertEqual(page_up, Ev2#dui_event.key),
    {[Ev3], <<>>} = educkui_escape_parser:parse(<<27, 91, "6~">>),
    ?assertEqual(page_down, Ev3#dui_event.key).

function_keys_test() ->
    {[Ev], <<>>} = educkui_escape_parser:parse(<<27, 91, "24~">>),
    ?assertEqual(f12, Ev#dui_event.key),
    {[Ev2], <<>>} = educkui_escape_parser:parse(<<27, 79, "P">>),
    ?assertEqual(f1, Ev2#dui_event.key).

modified_arrow_test() ->
    %% ESC [ 1 ; 5 A  =>  up + ctrl
    {[Ev], <<>>} = educkui_escape_parser:parse(<<27, 91, "1;5A">>),
    ?assertEqual(up, Ev#dui_event.key),
    ?assertEqual([ctrl], Ev#dui_event.modifiers).

sgr_mouse_press_test() ->
    %% ESC [ < 0 ; 1 ; 1 M  =>  left press at (0, 0)
    {[Ev], <<>>} = educkui_escape_parser:parse(<<27, 91, 60, 48, 59, 49, 59, 49, 77>>),
    ?assertEqual(mouse, Ev#dui_event.type),
    ?assertEqual(press, Ev#dui_event.action),
    ?assertEqual(left, Ev#dui_event.button),
    ?assertEqual(0, Ev#dui_event.x),
    ?assertEqual(0, Ev#dui_event.y).

sgr_mouse_scroll_test() ->
    %% ESC [ < 64 ; 1 ; 1 M  =>  scroll up
    {[Ev], <<>>} = educkui_escape_parser:parse(<<27, 91, 60, 54, 52, 59, 49, 59, 49, 77>>),
    ?assertEqual(scroll_up, Ev#dui_event.action),
    ?assertEqual(undefined, Ev#dui_event.button).

bracketed_paste_test() ->
    Input = <<27, 91, "200~", "hello", 27, 91, "201~">>,
    {[Ev], <<>>} = educkui_escape_parser:parse(Input),
    ?assertEqual(paste, Ev#dui_event.type),
    ?assertEqual(<<"hello">>, Ev#dui_event.content).

partial_sequence_test() ->
    ?assertEqual({[], <<27, 91>>}, educkui_escape_parser:parse(<<27, 91>>)),
    ?assert(educkui_escape_parser:partial_sequence(<<27, 91>>)),
    ?assertNot(educkui_escape_parser:partial_sequence(<<"a">>)).

alt_key_test() ->
    {[Ev], <<>>} = educkui_escape_parser:parse(<<27, "a">>),
    ?assertEqual(<<"a">>, Ev#dui_event.key),
    ?assertEqual([alt], Ev#dui_event.modifiers).

multiple_events_test() ->
    {Events, <<>>} = educkui_escape_parser:parse(<<"ab">>),
    ?assertEqual(2, length(Events)),
    ?assertEqual(<<"a">>, (hd(Events))#dui_event.key),
    ?assertEqual(<<"b">>, (lists:nth(2, Events))#dui_event.key).
