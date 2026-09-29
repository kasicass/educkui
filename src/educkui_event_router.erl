%% @doc Routes events to components.
%%
%% Key/focus events are routed to the currently focused component; mouse
%% events are hit-tested against the target rectangles provided by the
%% caller. The routing decision is pure and easy to test.
-module(educkui_event_router).

-include("educkui.hrl").

-export([route/3]).

-spec route(#dui_event{}, educkui_focus:focus_stack(), [{term(), #dui_rect{}}]) ->
    {route, term(), #dui_event{}} | ignore.
route(#dui_event{type = mouse, x = X, y = Y} = Event, _Focus, Targets) ->
    case educkui_mouse:find_target(X, Y, Targets) of
        {ok, Id, _Rect} -> {route, Id, Event};
        none -> ignore
    end;
route(#dui_event{type = key} = Event, Focus, _Targets) ->
    case educkui_focus:current(Focus) of
        undefined -> ignore;
        Id -> {route, Id, Event}
    end;
route(#dui_event{type = paste} = Event, Focus, _Targets) ->
    case educkui_focus:current(Focus) of
        undefined -> ignore;
        Id -> {route, Id, Event}
    end;
%% Messages addressed to a specific component (`educkui_runtime:send_message/3`)
%% are routed to that component regardless of focus.
route(#dui_event{type = custom, key = message, content = {Id, _Msg}} = Event,
      _Focus, _Targets) ->
    {route, Id, Event};
route(_Event, _Focus, _Targets) ->
    ignore.
