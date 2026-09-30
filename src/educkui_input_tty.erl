%% @doc TTY (line-based) input handler for constrained environments.
%%
%% Reads whole lines via `io:get_line/1' using a persistent reader process.
%% Each line is emitted as a custom event carrying the line content; key
%% parsing is not possible in cooked mode without raw terminal control.
-module(educkui_input_tty).

-behaviour(educkui_input).

-include("educkui.hrl").

-export([new/0, poll/2, mode/1, stop/1, feed/2, flush_partial/1]).
-export([start_reader/1]).

%% ---------------------------------------------------------------------------
%% API
%% ---------------------------------------------------------------------------

-spec new() -> map().
new() ->
    #{event_queue => []}.

-spec start_reader(pid()) -> pid().
start_reader(Owner) when is_pid(Owner) ->
    spawn_link(fun() -> reader_loop(Owner) end).

-spec poll(map(), non_neg_integer()) -> educkui_input:poll_result().
poll(#{event_queue := [Event | Rest]} = State, _Timeout) ->
    {{ok, Event}, State#{event_queue := Rest}};
poll(State, Timeout) ->
    receive
        {educkui_input, eof} ->
            {eof, State};
        {educkui_input, Data} when is_binary(Data) ->
            Event = educkui_event:custom(line, Data),
            {{ok, Event}, State}
    after Timeout ->
        {timeout, State}
    end.

%% @doc Feeds a whole line into the handler, producing one custom event.
-spec feed(map(), binary()) -> {[#dui_event{}], map()}.
feed(State, Data) when is_binary(Data) ->
    {[educkui_event:custom(line, Data)], State}.

%% @doc TTY input has no partial-escape buffering; nothing to flush.
-spec flush_partial(map()) -> {[#dui_event{}], map()}.
flush_partial(State) -> {[], State}.

-spec mode(map()) -> tty.
mode(_State) -> tty.

-spec stop(map()) -> ok.
stop(_State) -> ok.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec reader_loop(pid()) -> no_return().
reader_loop(Owner) ->
    case io:get_line(user, <<>>) of
        eof ->
            Owner ! {educkui_input, eof};
        {error, _} ->
            Owner ! {educkui_input, eof};
        Data ->
            Owner ! {educkui_input, iolist_to_binary(Data)},
            reader_loop(Owner)
    end.
