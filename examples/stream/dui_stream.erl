%% @doc Streaming data showcase.
%%
%% A producer process feeds the stream widget through
%% `educkui_runtime:send_message/3`. The widget keeps a bounded buffer,
%% renders live statistics and supports pause/clear/scroll.
%%
%% Controls:
%% - Space: pause/resume
%% - c: clear buffer
%% - s: toggle statistics
%% - Up/Down/PageUp/PageDown/Home/End: scroll
%% - Esc: quit
-module(dui_stream).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) ->
    %% `init/1` runs inside the runtime process, so `self()` is the runtime.
    Runtime = self(),
    _Producer = spawn(fun() -> producer_loop(Runtime, 0) end),
    #{}.

event_to_msg(#dui_event{type = key, key = esc}, _State) -> {msg, quit};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) -> {State, [educkui_command:quit()]};
update(_Msg, State) -> {State, []}.

view(_State) ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(
            <<"Stream - Space pause, c clear, s stats, Esc quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"">>),
        educkui_render_node:component(stream, educkui_widget_stream, #{
            buffer_size => 100,
            height => 12
        })
    ]).

producer_loop(Runtime, N) ->
    Ref = erlang:monitor(process, Runtime),
    producer_loop(Runtime, Ref, N).

producer_loop(Runtime, Ref, N) ->
    receive
        {'DOWN', Ref, process, Runtime, _Reason} ->
            ok
    after 200 ->
        Data = <<"event-", (integer_to_binary(N))/binary>>,
        educkui_runtime:send_message(Runtime, stream, {stream_item, Data}),
        producer_loop(Runtime, Ref, N + 1)
    end.
