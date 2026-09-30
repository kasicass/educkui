%% @doc Event constructors.
%%
%% Events represent terminal input (keys, mouse, focus changes), resize
%% notifications, clipboard pastes, timer ticks and application-defined
%% custom events. They are implemented as tagged `#dui_event{}' records.
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

%% @doc Creates a key event.
-spec key(atom() | binary()) -> #dui_event{}.
key(Key) -> key(Key, []).

%% @doc Creates a key event with options.
-spec key(atom() | binary(), [{atom(), term()}]) -> #dui_event{}.
key(Key, Opts) ->
    #dui_event{
        type = key,
        key = Key,
        char = proplists:get_value(char, Opts),
        modifiers = proplists:get_value(modifiers, Opts, []),
        timestamp = timestamp(Opts)
    }.

%% @doc Creates a mouse event.
-spec mouse(atom(), atom() | undefined, integer(), integer()) -> #dui_event{}.
mouse(Action, Button, X, Y) -> mouse(Action, Button, X, Y, []).

%% @doc Creates a mouse event with options.
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

%% @doc Creates a focus event.
-spec focus(atom()) -> #dui_event{}.
focus(Action) -> focus(Action, []).

%% @doc Creates a focus event with options.
-spec focus(atom(), [{atom(), term()}]) -> #dui_event{}.
focus(Action, Opts) ->
    #dui_event{type = focus, action = Action, timestamp = timestamp(Opts)}.

%% @doc Creates a resize event.
-spec resize(pos_integer(), pos_integer()) -> #dui_event{}.
resize(Width, Height) -> resize(Width, Height, []).

%% @doc Creates a resize event with options.
-spec resize(pos_integer(), pos_integer(), [{atom(), term()}]) -> #dui_event{}.
resize(Width, Height, Opts) ->
    #dui_event{
        type = resize,
        width = Width,
        height = Height,
        timestamp = timestamp(Opts)
    }.

%% @doc Creates a paste event.
-spec paste(binary()) -> #dui_event{}.
paste(Content) -> paste(Content, []).

%% @doc Creates a paste event with options.
-spec paste(binary(), [{atom(), term()}]) -> #dui_event{}.
paste(Content, Opts) ->
    #dui_event{type = paste, content = Content, timestamp = timestamp(Opts)}.

%% @doc Creates a tick event.
-spec tick(pos_integer()) -> #dui_event{}.
tick(Interval) -> tick(Interval, []).

%% @doc Creates a tick event with options.
-spec tick(pos_integer(), [{atom(), term()}]) -> #dui_event{}.
tick(Interval, Opts) ->
    #dui_event{type = tick, interval = Interval, timestamp = timestamp(Opts)}.

%% @doc Creates a custom event.
-spec custom(atom(), term()) -> #dui_event{}.
custom(Name, Payload) -> custom(Name, Payload, []).

%% @doc Creates a custom event with options.
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

%% @doc Returns the event timestamp in milliseconds.
-spec timestamp([{atom(), term()}]) -> integer().
timestamp(Opts) ->
    proplists:get_value(timestamp, Opts, erlang:monotonic_time(millisecond)).
