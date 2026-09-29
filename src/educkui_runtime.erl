%% @doc Central runtime orchestrator.
%%
%% Implements the Elm Architecture dispatch loop:
%%
%%   1. receive an event (terminal input, command result, ...)
%%   2. route it to the root component
%%   3. call `event_to_msg/2`, then `update/2`
%%   4. collect and execute commands
%%   5. on each render tick, call `view/1` and rasterize to the buffer
%%   6. draw changed cells to the backend (double buffering)
-module(educkui_runtime).

-behaviour(gen_server).

-include("educkui.hrl").

-export([
    start_link/1,
    run/1,
    send_event/2,
    send_message/3,
    shutdown/1,
    sync/1,
    get_state/1,
    force_render/1,
    backend_mode/0,
    capabilities/0
]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% ---------------------------------------------------------------------------
%% Client API
%% ---------------------------------------------------------------------------

-spec start_link([{atom(), term()}]) -> gen_server:start_ret().
start_link(Opts) ->
    gen_server:start_link(?MODULE, Opts, []).

%% @doc Starts the runtime and blocks until it exits.
-spec run([{atom(), term()}]) -> ok | {error, term()}.
run(Opts) ->
    case start_link(Opts) of
        {ok, Pid} ->
            Ref = erlang:monitor(process, Pid),
            receive
                {'DOWN', Ref, process, Pid, _Reason} -> ok
            end;
        {error, Reason} ->
            {error, Reason}
    end.

-spec send_event(pid(), #dui_event{}) -> ok.
send_event(Runtime, Event) ->
    gen_server:cast(Runtime, {event, Event}).

-spec send_message(pid(), term(), term()) -> ok.
send_message(Runtime, ComponentId, Message) ->
    gen_server:cast(Runtime, {message, ComponentId, Message}).

-spec shutdown(pid()) -> ok.
shutdown(Runtime) ->
    gen_server:cast(Runtime, shutdown).

-spec sync(pid()) -> ok.
sync(Runtime) ->
    gen_server:call(Runtime, sync).

-spec get_state(pid()) -> #dui_runtime_state{}.
get_state(Runtime) ->
    gen_server:call(Runtime, get_state).

-spec force_render(pid()) -> ok.
force_render(Runtime) ->
    gen_server:cast(Runtime, force_render).

-spec backend_mode() -> raw | tty | skip | undefined.
backend_mode() ->
    persistent_term:get({educkui, backend_mode}, undefined).

-spec capabilities() -> map() | undefined.
capabilities() ->
    persistent_term:get({educkui, capabilities}, undefined).

%% ---------------------------------------------------------------------------
%% gen_server callbacks
%% ---------------------------------------------------------------------------

-spec init([{atom(), term()}]) -> {ok, #dui_runtime_state{}} | {stop, term()}.
init(Opts) ->
    process_flag(trap_exit, true),
    Merged = educkui_config:merge_options(Opts),
    RootModule = proplists:get_value(root, Merged),
    RenderInterval = proplists:get_value(render_interval, Merged, 16),
    SkipTerminal = proplists:get_value(skip_terminal, Merged, false),
    BackendOpt = proplists:get_value(backend, Merged, auto),

    case init_backend(BackendOpt, SkipTerminal, Merged) of
        {error, Reason} ->
            {stop, Reason};
        {ok, BackendMode, Backend, BackendState, Dimensions, TerminalStarted} ->
            init_after_backend(#{
                root_module => RootModule,
                render_interval => RenderInterval,
                skip_terminal => SkipTerminal,
                backend_mode => BackendMode,
                backend => Backend,
                backend_state => BackendState,
                dimensions => Dimensions,
                terminal_started => TerminalStarted,
                merged => Merged
            })
    end.

-spec init_after_backend(map()) -> {ok, #dui_runtime_state{}}.
init_after_backend(#{root_module := RootModule} = Ctx) ->
    #{
        render_interval := RenderInterval,
        backend_mode := BackendMode,
        backend := Backend,
        backend_state := BackendState,
        dimensions := Dimensions,
        terminal_started := TerminalStarted,
        merged := Merged
    } = Ctx,

    {CurrentBuf, PreviousBuf} = create_buffers(Dimensions),

    {ok, Executor} = educkui_command_executor:start_link(),

    InitResult = RootModule:init(proplists:get_value(init_args, Merged, [])),
    {RootState, InitCommands} = educkui_elm:normalize_init_result(InitResult),

    {InputHandler, InputState, InputReader} = init_input(BackendMode),

    Capabilities = case BackendMode of
        skip -> undefined;
        _ -> educkui_capabilities:detect()
    end,

    persistent_term:put({educkui, backend_mode}, BackendMode),
    persistent_term:put({educkui, capabilities}, Capabilities),

    State = #dui_runtime_state{
        root_module = RootModule,
        root_state = RootState,
        render_interval = RenderInterval,
        terminal_started = TerminalStarted,
        current_buffer = CurrentBuf,
        previous_buffer = PreviousBuf,
        dimensions = Dimensions,
        backend_mode = BackendMode,
        backend = Backend,
        backend_state = BackendState,
        input_handler = InputHandler,
        input_state = InputState,
        input_reader = InputReader,
        command_executor = Executor,
        capabilities = Capabilities,
        dirty = true,
        last_render = undefined,
        focus = [root],
        targets = []
    },

    erlang:send_after(RenderInterval, self(), render_tick),

    State1 = execute_commands(root, InitCommands, State),
    {ok, State1}.

handle_call(sync, _From, State) ->
    {reply, ok, State};
handle_call(get_state, _From, State) ->
    {reply, State, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({event, Event}, State) ->
    {noreply, process_event(Event, State)};
handle_cast({message, ComponentId, Message}, State) ->
    {noreply, process_event(educkui_event:custom(message, {ComponentId, Message}), State)};
handle_cast(force_render, State) ->
    {noreply, do_render(State)};
handle_cast(shutdown, State) ->
    {stop, normal, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(render_tick, State) ->
    Now = educkui_framerate_limiter:monotonic_ms(),
    ShouldRender =
        State#dui_runtime_state.dirty andalso
        educkui_framerate_limiter:should_render(
            State#dui_runtime_state.last_render, State#dui_runtime_state.render_interval),
    State1 = case ShouldRender of
        true -> do_render(State#dui_runtime_state{last_render = Now});
        false -> State
    end,
    erlang:send_after(State1#dui_runtime_state.render_interval, self(), render_tick),
    {noreply, State1};
handle_info({educkui_input, eof}, State) ->
    {stop, normal, State};
handle_info({educkui_input, Data}, State) when is_binary(Data) ->
    State1 = feed_input(State, Data),
    {noreply, State1};
handle_info({educkui_command, quit}, State) ->
    {stop, normal, State};
handle_info({command_result, ComponentId, Result}, State) ->
    Event = educkui_event:custom(command_result, {ComponentId, Result}),
    {noreply, process_event(Event, State)};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
    cleanup(State),
    ok.

%% ---------------------------------------------------------------------------
%% Backend setup
%% ---------------------------------------------------------------------------

-spec init_backend(atom(), boolean(), [{atom(), term()}]) ->
    {ok, raw | tty | skip, module() | undefined, term(), {pos_integer(), pos_integer()},
     boolean()} | {error, term()}.
init_backend(_BackendOpt, true, _Merged) ->
    {ok, skip, undefined, undefined, {24, 80}, false};
init_backend(BackendOpt, false, Merged) ->
    {ok, _TermPid} = educkui_terminal:start_link(),
    case educkui_backend_selector:select(BackendOpt) of
        {ok, {Mode, BackendMod}} ->
            BackendOpts = [{size, backend_size(Merged)}],
            case BackendMod:init(BackendOpts) of
                {ok, BState} ->
                    {ok, Dims} = BackendMod:size(BState),
                    {ok, Mode, BackendMod, BState, Dims, true};
                {error, Reason} ->
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

-spec backend_size([{atom(), term()}]) -> {pos_integer(), pos_integer()} | undefined.
backend_size(Merged) ->
    case proplists:get_value(size, Merged, undefined) of
        {Rows, Cols} when Rows > 0, Cols > 0 -> {Rows, Cols};
        _ -> undefined
    end.

-spec init_input(raw | tty | skip) -> {module() | undefined, term(), pid() | undefined}.
init_input(skip) ->
    {undefined, undefined, undefined};
init_input(BackendMode) when BackendMode =:= raw; BackendMode =:= tty ->
    Handler = case BackendMode of
        raw -> educkui_input_raw;
        tty -> educkui_input_tty
    end,
    InputState = Handler:new(),
    Reader = Handler:start_reader(self()),
    {Handler, InputState, Reader}.

%% ---------------------------------------------------------------------------
%% Event processing
%% ---------------------------------------------------------------------------

-spec process_event(#dui_event{}, #dui_runtime_state{}) -> #dui_runtime_state{}.
process_event(#dui_event{type = resize} = Event, State) ->
    handle_resize(Event, State);
process_event(Event, State) ->
    case educkui_event_router:route(Event, State#dui_runtime_state.focus,
                                    State#dui_runtime_state.targets) of
        ignore -> State;
        {route, root, RoutedEvent} -> dispatch_root(RoutedEvent, State);
        {route, _Other, _RoutedEvent} -> State
    end.

-spec dispatch_root(#dui_event{}, #dui_runtime_state{}) -> #dui_runtime_state{}.
dispatch_root(Event, State) ->
    RootModule = State#dui_runtime_state.root_module,
    RootState = State#dui_runtime_state.root_state,
    case RootModule:event_to_msg(Event, RootState) of
        {msg, Msg} ->
            UpdateResult = RootModule:update(Msg, RootState),
            {NewState, Commands} = educkui_elm:normalize_update_result(UpdateResult, RootState),
            State1 = State#dui_runtime_state{root_state = NewState, dirty = true},
            execute_commands(root, Commands, State1);
        ignore ->
            State;
        propagate ->
            State
    end.

-spec execute_commands(term(), [term()], #dui_runtime_state{}) -> #dui_runtime_state{}.
execute_commands(_ComponentId, [], State) ->
    State;
execute_commands(ComponentId, Commands, State) ->
    educkui_command_executor:execute(ComponentId, Commands, self()),
    State.

-spec handle_resize(#dui_event{}, #dui_runtime_state{}) -> #dui_runtime_state{}.
handle_resize(#dui_event{width = W, height = H}, State) when W > 0, H > 0 ->
    {ok, NewCur} = educkui_buffer:resize(State#dui_runtime_state.current_buffer, H, W),
    {ok, NewPrev} = educkui_buffer:resize(State#dui_runtime_state.previous_buffer, H, W),
    State#dui_runtime_state{
        dimensions = {H, W},
        current_buffer = NewCur,
        previous_buffer = NewPrev,
        dirty = true
    };
handle_resize(_Event, State) ->
    State.

-spec feed_input(#dui_runtime_state{}, binary()) -> #dui_runtime_state{}.
feed_input(#dui_runtime_state{input_handler = Handler, input_state = InputState} = State,
           Data) ->
    case Handler of
        undefined ->
            State;
        _ ->
            {Events, NewInputState} = Handler:feed(InputState, Data),
            lists:foldl(
                fun(Event, AccState) -> process_event(Event, AccState) end,
                State#dui_runtime_state{input_state = NewInputState},
                Events)
    end.

%% ---------------------------------------------------------------------------
%% Rendering
%% ---------------------------------------------------------------------------

-spec do_render(#dui_runtime_state{}) -> #dui_runtime_state{}.
do_render(#dui_runtime_state{root_module = RootModule, root_state = RootState,
                             dimensions = {Rows, Cols}} = State) ->
    View = RootModule:view(RootState),
    Rect = #dui_rect{width = Cols, height = Rows},
    Cells = educkui_render:render(View, Rect),

    Cur = State#dui_runtime_state.current_buffer,
    Prev = State#dui_runtime_state.previous_buffer,
    educkui_buffer:clear(Cur),
    educkui_buffer:set_cells(Cur, [{X + 1, Y + 1, Cell} || {X, Y, Cell} <- Cells]),

    State1 = output_changed(State, changed_cells(Cur, Prev, Rows, Cols)),
    State1#dui_runtime_state{
        current_buffer = Prev,
        previous_buffer = Cur,
        dirty = false
    }.

-spec output_changed(#dui_runtime_state{},
    [{educkui_backend:position(), #dui_cell{}}]) -> #dui_runtime_state{}.
output_changed(#dui_runtime_state{backend = undefined} = State, _Changed) ->
    State;
output_changed(#dui_runtime_state{backend = Backend, backend_state = BState} = State, []) ->
    _ = Backend:flush(BState),
    State;
output_changed(#dui_runtime_state{backend = Backend, backend_state = BState} = State,
               Changed) ->
    {ok, BState1} = Backend:draw_cells(BState, Changed),
    {ok, BState2} = Backend:flush(BState1),
    State#dui_runtime_state{backend_state = BState2}.

-spec changed_cells(#dui_buffer{}, #dui_buffer{}, pos_integer(), pos_integer()) ->
    [{educkui_backend:position(), #dui_cell{}}].
changed_cells(Cur, Prev, Rows, Cols) ->
    lists:flatmap(
        fun(Row) ->
            CurRow = educkui_buffer:get_row(Cur, Row),
            PrevRow = educkui_buffer:get_row(Prev, Row),
            [{ {Row, Col}, Cell}
             || {Col, Cell, PrevCell} <- lists:zip3(lists:seq(1, Cols), CurRow, PrevRow),
                not educkui_cell:equal(Cell, PrevCell)]
        end,
        lists:seq(1, Rows)).

%% ---------------------------------------------------------------------------
%% Helpers / cleanup
%% ---------------------------------------------------------------------------

-spec create_buffers({pos_integer(), pos_integer()}) -> {#dui_buffer{}, #dui_buffer{}}.
create_buffers({Rows, Cols}) ->
    {ok, Cur} = educkui_buffer:new(Rows, Cols),
    {ok, Prev} = educkui_buffer:new(Rows, Cols),
    {Cur, Prev}.

-spec cleanup(#dui_runtime_state{}) -> ok.
cleanup(State) ->
    catch stop_reader(State#dui_runtime_state.input_reader),
    catch shutdown_backend(State#dui_runtime_state.backend, State#dui_runtime_state.backend_state),
    catch restore_terminal(State#dui_runtime_state.terminal_started),
    catch stop_executor(State#dui_runtime_state.command_executor),
    catch destroy_buffers(State#dui_runtime_state.current_buffer,
                          State#dui_runtime_state.previous_buffer),
    persistent_term:erase({educkui, backend_mode}),
    persistent_term:erase({educkui, capabilities}),
    ok.

-spec stop_reader(pid() | undefined) -> ok.
stop_reader(undefined) -> ok;
stop_reader(Pid) ->
    exit(Pid, kill),
    ok.

-spec shutdown_backend(module() | undefined, term()) -> ok.
shutdown_backend(undefined, _BState) -> ok;
shutdown_backend(Backend, BState) ->
    _ = Backend:shutdown(BState),
    ok.

-spec restore_terminal(boolean()) -> ok.
restore_terminal(true) ->
    _ = educkui_terminal:restore(),
    catch gen_server:stop(educkui_terminal),
    ok;
restore_terminal(false) ->
    ok.

-spec stop_executor(pid() | undefined) -> ok.
stop_executor(undefined) -> ok;
stop_executor(Pid) ->
    catch gen_server:stop(Pid),
    ok.

-spec destroy_buffers(#dui_buffer{} | undefined, #dui_buffer{} | undefined) -> ok.
destroy_buffers(undefined, _Prev) -> ok;
destroy_buffers(Cur, Prev) ->
    educkui_buffer:destroy(Cur),
    educkui_buffer:destroy(Prev),
    ok.
