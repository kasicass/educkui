%% @doc Raw-mode input handler.
%%
%% Reads single characters from stdin via `io:get_chars/3` using a persistent
%% reader process that forwards `{educkui_input, Data}` messages to the owner.
%% `poll/2` pops queued events, tries to complete a buffered escape sequence,
%% and otherwise waits for input with a timeout.
-module(educkui_input_raw).

-behaviour(educkui_input).

-include("educkui.hrl").

-export([new/0, poll/2, mode/1, stop/1]).
-export([start_reader/1]).

%% ---------------------------------------------------------------------------
%% API
%% ---------------------------------------------------------------------------

-spec new() -> map().
new() ->
    #{buffer => <<>>, event_queue => []}.

-spec start_reader(pid()) -> pid().
start_reader(Owner) when is_pid(Owner) ->
    spawn_link(fun() -> reader_loop(Owner) end).

-spec poll(map(), non_neg_integer()) -> educkui_input:poll_result().
poll(#{event_queue := [Event | Rest]} = State, _Timeout) ->
    {{ok, Event}, State#{event_queue := Rest}};
poll(State, Timeout) ->
    case try_parse_buffer(State) of
        {ok, Event, NewState} ->
            {{ok, Event}, NewState};
        need_more ->
            receive
                {educkui_input, eof} ->
                    {eof, State};
                {educkui_input, Data} when is_binary(Data) ->
                    handle_data(State, Data)
            after Timeout ->
                {timeout, State}
            end
    end.

-spec mode(map()) -> raw.
mode(_State) -> raw.

-spec stop(map()) -> ok.
stop(_State) -> ok.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec reader_loop(pid()) -> no_return().
reader_loop(Owner) ->
    case io:get_chars(user, <<>>, 1) of
        eof ->
            Owner ! {educkui_input, eof};
        Data ->
            Owner ! {educkui_input, Data},
            reader_loop(Owner)
    end.

-spec try_parse_buffer(map()) ->
    {ok, #dui_event{}, map()} | need_more.
try_parse_buffer(#{buffer := Buffer} = State) ->
    case educkui_escape_parser:parse(Buffer) of
        {[Event | Rest], Remaining} ->
            {ok, Event, State#{buffer := Remaining,
                               event_queue := Rest}};
        {[], Remaining} ->
            case Remaining =:= Buffer of
                true -> need_more;
                false -> try_parse_buffer(State#{buffer := Remaining})
            end
    end.

-spec handle_data(map(), binary()) -> educkui_input:poll_result().
handle_data(#{buffer := Buffer} = State, Data) ->
    Combined = <<Buffer/binary, Data/binary>>,
    case educkui_escape_parser:parse(Combined) of
        {[Event | Rest], Remaining} ->
            {{ok, Event}, State#{buffer := Remaining, event_queue := Rest}};
        {[], Remaining} ->
            case Remaining =:= Combined of
                true -> {timeout, State#{buffer := Remaining}};
                false ->
                    %% Parser consumed some bytes but produced no event;
                    %% keep the remainder and report timeout.
                    {timeout, State#{buffer := Remaining}}
            end
    end.


