%% @doc Framerate throttle helper.
%%
%% The runtime schedules render ticks with `erlang:send_after/3`; this module
%% provides the pure timing predicate used to decide whether a scheduled tick
%% should actually render, so that back-to-back dirty frames coalesce into a
%% single render at most once per interval.
-module(educkui_framerate_limiter).

-export([default_interval/0, monotonic_ms/0, should_render/2]).

-spec default_interval() -> pos_integer().
default_interval() -> 16.

-spec monotonic_ms() -> integer().
monotonic_ms() ->
    erlang:monotonic_time(millisecond).

%% @doc Returns true if `Interval` milliseconds have elapsed since
%% `LastRender` (or if there has been no previous render).
-spec should_render(integer() | undefined, pos_integer()) -> boolean().
should_render(undefined, _Interval) ->
    true;
should_render(LastRender, Interval) when is_integer(Interval), Interval > 0 ->
    erlang:monotonic_time(millisecond) - LastRender >= Interval.
