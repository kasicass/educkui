%% @doc Headless test harness for educkui applications.
%%
%% Starts a runtime with the `skip' backend and a fixed virtual size, then
%% exposes helpers to drive events and assert on the rendered screen. This
%% lets EUnit/Common Test suites exercise a whole application without a real
%% terminal.
%%
%% Example:
%%
%% ```
%% Pid = educkui_test:start(#{root => my_app, size => {24, 80}}),
%% ok = educkui_test:send_key(Pid, down),
%% ok = educkui_test:assert_text(Pid, <<"Selected">>),
%% ok = educkui_test:stop(Pid).
%% '''
-module(educkui_test).

-include("educkui.hrl").

-export([
    start/0, start/1, stop/1,
    send_key/2, send_keys/2, send_event/2, send_msg/2,
    sync/1, render/1,
    screen_cells/1, screen_text/1,
    assert_text/2, assert_text/3,
    wait_until/2, wait_until/3
]).

-type opt() :: {root, module()} | {size, {pos_integer(), pos_integer()}}
             | {init_args, [{atom(), term()}]} | {render_interval, pos_integer()}
             | {extra_opts, [{atom(), term()}]}.
-export_type([opt/0]).

%% @doc Starts a runtime with default options (24x80, no root).
-spec start() -> pid().
start() -> start(#{}).

%% @doc Starts a headless runtime for `root'.
-spec start(#{atom() => term()}) -> pid().
start(Opts) ->
    Root = maps:get(root, Opts),
    Size = maps:get(size, Opts, {24, 80}),
    Base = [{root, Root}, {skip_terminal, true}, {size, Size}],
    Extra = maps:get(init_args, Opts, []),
    RuntimeOpts = Base
        ++ [{init_args, Extra} || Extra =/= []]
        ++ maps:get(extra_opts, Opts, []),
    {ok, Pid} = educkui_runtime:start_link(RuntimeOpts),
    Pid.

%% @doc Stops a runtime and waits for it to exit.
-spec stop(pid()) -> ok.
stop(Pid) ->
    ok = educkui_runtime:shutdown(Pid),
    Ref = erlang:monitor(process, Pid),
    receive
        {'DOWN', Ref, process, Pid, _Reason} -> ok
    after 2000 ->
        ok
    end.

%% @doc Sends a key event (atom or binary) to the runtime.
-spec send_key(pid(), atom() | binary()) -> ok.
send_key(Pid, Key) ->
    educkui_runtime:send_event(Pid, educkui_event:key(Key)).

%% @doc Sends several key events in order.
-spec send_keys(pid(), [atom() | binary()]) -> ok.
send_keys(Pid, Keys) ->
    lists:foreach(fun(Key) -> ok = send_key(Pid, Key) end, Keys).

%% @doc Sends a raw event.
-spec send_event(pid(), #dui_event{}) -> ok.
send_event(Pid, Event) ->
    educkui_runtime:send_event(Pid, Event).

%% @doc Sends a directed message to the root component.
-spec send_msg(pid(), term()) -> ok.
send_msg(Pid, Msg) ->
    educkui_runtime:send_message(Pid, root, Msg).

%% @doc Synchronously waits for all prior requests to be processed.
-spec sync(pid()) -> ok.
sync(Pid) ->
    educkui_runtime:sync(Pid).

%% @doc Forces a render and waits for it to complete.
-spec render(pid()) -> ok.
render(Pid) ->
    ok = educkui_runtime:sync(Pid),
    ok = educkui_runtime:force_render(Pid),
    ok = educkui_runtime:sync(Pid).

%% @doc Returns the last rendered frame as `{X, Y, #dui_cell{}}' (0-based).
-spec screen_cells(pid()) -> [{non_neg_integer(), non_neg_integer(), #dui_cell{}}].
screen_cells(Pid) ->
    ok = render(Pid),
    Buffer = current_frame_buffer(Pid),
    {Rows, Cols} = educkui_buffer:dimensions(Buffer),
    lists:flatmap(
        fun(Row) ->
            Cells = educkui_buffer:get_row(Buffer, Row),
            [ {Col - 1, Row - 1, Cell}
              || {Col, Cell} <- lists:zip(lists:seq(1, Cols), Cells)]
        end,
        lists:seq(1, Rows)).

%% @doc Returns the last rendered frame as plain text (trailing spaces trimmed).
-spec screen_text(pid()) -> binary().
screen_text(Pid) ->
    ok = render(Pid),
    Buffer = current_frame_buffer(Pid),
    {Rows, _Cols} = educkui_buffer:dimensions(Buffer),
    Lines = [row_text(educkui_buffer:get_row(Buffer, Row)) || Row <- lists:seq(1, Rows)],
    iolist_to_binary(lists:join(<<"\n">>, Lines)).

%% @doc Returns `ok' if `Substring' appears in the rendered screen.
-spec assert_text(pid(), binary()) -> ok | {error, {not_found, binary()}}.
assert_text(Pid, Substring) ->
    Text = screen_text(Pid),
    case binary:match(Text, Substring) of
        nomatch -> {error, {not_found, Substring}};
        _ -> ok
    end.

%% @doc Like `assert_text/2' but raises with `Context' on failure.
-spec assert_text(pid(), binary(), term()) -> ok.
assert_text(Pid, Substring, Context) ->
    case assert_text(Pid, Substring) of
        ok -> ok;
        {error, Reason} -> erlang:error({assert_text_failed, Reason, Context})
    end.

%% @doc Polls `Pred(State)' (the root component state) until it returns true.
-spec wait_until(pid(), fun((term()) -> boolean())) -> ok | {error, timeout}.
wait_until(Pid, Pred) ->
    wait_until(Pid, Pred, 100).

%% @doc Like `wait_until/2' with an explicit number of ~10ms attempts.
-spec wait_until(pid(), fun((term()) -> boolean()), non_neg_integer()) ->
    ok | {error, timeout}.
wait_until(_Pid, _Pred, 0) ->
    {error, timeout};
wait_until(Pid, Pred, Attempts) ->
    ok = sync(Pid),
    State = educkui_runtime:get_state(Pid),
    case Pred(State#dui_runtime_state.root_state) of
        true -> ok;
        false ->
            timer:sleep(10),
            wait_until(Pid, Pred, Attempts - 1)
    end.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec current_frame_buffer(pid()) -> #dui_buffer{}.
current_frame_buffer(Pid) ->
    State = educkui_runtime:get_state(Pid),
    %% After a render the just-drawn frame lives in `previous_buffer'.
    State#dui_runtime_state.previous_buffer.

-spec row_text([#dui_cell{}]) -> binary().
row_text(Cells) ->
    Bin = iolist_to_binary([cell_char(C) || C <- Cells]),
    string:trim(Bin, trailing, " ").

-spec cell_char(#dui_cell{}) -> binary().
cell_char(#dui_cell{placeholder = true}) -> <<>>;
cell_char(#dui_cell{char = Char}) -> Char.
