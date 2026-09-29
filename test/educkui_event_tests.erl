-module(educkui_event_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

key_event_test() ->
    Ev = educkui_event:key(up),
    ?assertEqual(key, Ev#dui_event.type),
    ?assertEqual(up, Ev#dui_event.key),
    ?assertEqual([], Ev#dui_event.modifiers).

key_event_with_opts_test() ->
    Ev = educkui_event:key(<<"a">>, [{char, <<"a">>}, {modifiers, [ctrl]}]),
    ?assertEqual(<<"a">>, Ev#dui_event.char),
    ?assertEqual([ctrl], Ev#dui_event.modifiers).

mouse_event_test() ->
    Ev = educkui_event:mouse(click, left, 10, 20),
    ?assertEqual(mouse, Ev#dui_event.type),
    ?assertEqual(click, Ev#dui_event.action),
    ?assertEqual(left, Ev#dui_event.button),
    ?assertEqual(10, Ev#dui_event.x),
    ?assertEqual(20, Ev#dui_event.y).

focus_event_test() ->
    Ev = educkui_event:focus(gained),
    ?assertEqual(focus, Ev#dui_event.type),
    ?assertEqual(gained, Ev#dui_event.action).

resize_event_test() ->
    Ev = educkui_event:resize(120, 40),
    ?assertEqual(resize, Ev#dui_event.type),
    ?assertEqual(120, Ev#dui_event.width),
    ?assertEqual(40, Ev#dui_event.height).

paste_event_test() ->
    Ev = educkui_event:paste(<<"hello">>),
    ?assertEqual(paste, Ev#dui_event.type),
    ?assertEqual(<<"hello">>, Ev#dui_event.content).

tick_event_test() ->
    Ev = educkui_event:tick(16),
    ?assertEqual(tick, Ev#dui_event.type),
    ?assertEqual(16, Ev#dui_event.interval).

custom_event_test() ->
    Ev = educkui_event:custom(submit, #{value => <<"x">>}),
    ?assertEqual(custom, Ev#dui_event.type),
    ?assertEqual(submit, Ev#dui_event.key),
    ?assertEqual(#{value => <<"x">>}, Ev#dui_event.content).

timestamp_default_test() ->
    Ev = educkui_event:key(up),
    %% monotonic_time/1 may be negative on some platforms; only the type
    %% matters here.
    ?assert(is_integer(Ev#dui_event.timestamp)).
