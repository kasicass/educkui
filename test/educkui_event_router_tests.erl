-module(educkui_event_router_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

key_to_focused_test() ->
    Focus = educkui_focus:focus(educkui_focus:new(), widget1),
    Event = educkui_event:key(up),
    ?assertEqual({route, widget1, Event},
                 educkui_event_router:route(Event, Focus, [])).

key_without_focus_test() ->
    ?assertEqual(ignore,
                 educkui_event_router:route(educkui_event:key(up),
                                            educkui_focus:new(), [])).

mouse_hit_test() ->
    Rect = #dui_rect{x = 0, y = 0, width = 10, height = 10},
    Event = educkui_event:mouse(click, left, 5, 5),
    ?assertEqual({route, button, Event},
                 educkui_event_router:route(Event, educkui_focus:new(),
                                            [{button, Rect}])).

mouse_miss_test() ->
    Rect = #dui_rect{x = 0, y = 0, width = 10, height = 10},
    Event = educkui_event:mouse(click, left, 50, 50),
    ?assertEqual(ignore,
                 educkui_event_router:route(Event, educkui_focus:new(),
                                            [{button, Rect}])).

paste_to_focused_test() ->
    Focus = educkui_focus:focus(educkui_focus:new(), input),
    Event = educkui_event:paste(<<"x">>),
    ?assertEqual({route, input, Event},
                 educkui_event_router:route(Event, Focus, [])).

message_to_component_test() ->
    Event = educkui_event:custom(message, {stream, {stream_item, <<"x">>}}),
    ?assertEqual({route, stream, Event},
                 educkui_event_router:route(Event, educkui_focus:new(), [])).
