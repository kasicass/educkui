%% @doc Event constructors.
%%
%% Events represent terminal input (keys, mouse, focus changes), resize
%% notifications, clipboard pastes, timer ticks and application-defined
%% custom events. They are implemented as tagged `#dui_event{}` records.
-module(educkui_event).

-include("educkui.hrl").

-export([
    key/1, key/2,
    mouse/4, mouse/5,
    focus/1, focus/2,
    resize/2, resize/3,
    paste/1, paste/2,
    tick/1, tick/2,
    custom/2, custom/3
]).

%% ---------------------------------------------------------------------------
%% Constructors
%% ---------------------------------------------------------------------------

-spec key(atom() | binary()) -> #dui_event{}.
key(Key) -> key(Key, []).

-spec key(atom() | binary(), [{atom(), term()}]) -> #dui_event{}.
key(Key, Opts) ->
    #dui_event{
        type = key,
        key = Key,
        char = proplists:get_value(char, Opts),
        modifiers = proplists:get_value(modifiers, Opts, []),
        timestamp = timestamp(Opts)
    }.

-spec mouse(atom(), atom() | undefined, integer(), integer()) -> #dui_event{}.
mouse(Action, Button, X, Y) -> mouse(Action, Button, X, Y, []).

-spec mouse(atom(), atom() | undefined, integer(), integer(), [{atom(), term()}]) ->
    #dui_event{}.
mouse(Action, Button, X, Y, Opts) ->
    #dui_event{
        type = mouse,
        action = Action,
        button = Button,
        x = X,
        y = Y,
        modifiers = proplists:get_value(modifiers, Opts, []),
        timestamp = timestamp(Opts)
    }.

-spec focus(atom()) -> #dui_event{}.
focus(Action) -> focus(Action, []).

-spec focus(atom(), [{atom(), term()}]) -> #dui_event{}.
focus(Action, Opts) ->
    #dui_event{type = focus, action = Action, timestamp = timestamp(Opts)}.

-spec resize(pos_integer(), pos_integer()) -> #dui_event{}.
resize(Width, Height) -> resize(Width, Height, []).

-spec resize(pos_integer(), pos_integer(), [{atom(), term()}]) -> #dui_event{}.
resize(Width, Height, Opts) ->
    #dui_event{
        type = resize,
        width = Width,
        height = Height,
        timestamp = timestamp(Opts)
    }.

-spec paste(binary()) -> #dui_event{}.
paste(Content) -> paste(Content, []).

-spec paste(binary(), [{atom(), term()}]) -> #dui_event{}.
paste(Content, Opts) ->
    #dui_event{type = paste, content = Content, timestamp = timestamp(Opts)}.

-spec tick(pos_integer()) -> #dui_event{}.
tick(Interval) -> tick(Interval, []).

-spec tick(pos_integer(), [{atom(), term()}]) -> #dui_event{}.
tick(Interval, Opts) ->
    #dui_event{type = tick, interval = Interval, timestamp = timestamp(Opts)}.

-spec custom(atom(), term()) -> #dui_event{}.
custom(Name, Payload) -> custom(Name, Payload, []).

-spec custom(atom(), term(), [{atom(), term()}]) -> #dui_event{}.
custom(Name, Payload, Opts) ->
    #dui_event{
        type = custom,
        key = Name,
        content = Payload,
        timestamp = timestamp(Opts)
    }.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec timestamp([{atom(), term()}]) -> integer().
timestamp(Opts) ->
    proplists:get_value(timestamp, Opts, erlang:monotonic_time(millisecond)).
